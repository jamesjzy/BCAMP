# Vyper version
# @version 0.2.4
"""
@title Voting Escrow with Exponential Decay
@notice Votes have a weight depending on time, using an exponential decay model.
"""

struct Point:
    bias: int128
    slope: int128  # - dweight / dt
    ts: uint256
    blk: uint256  # block

struct LockedBalance:
    amount: int128
    end: uint256

interface ERC20:
    def decimals() -> uint256: view
    def name() -> String[64]: view
    def symbol() -> String[32]: view
    def transfer(to: address, amount: uint256) -> bool: nonpayable
    def transferFrom(spender: address, to: address, amount: uint256) -> bool: nonpayable

interface SmartWalletChecker:
    def check(addr: address) -> bool: nonpayable

event CommitOwnership:
    admin: address

event ApplyOwnership:
    admin: address

event Deposit:
    provider: indexed(address)
    value: uint256
    locktime: indexed(uint256)
    type: int128
    ts: uint256

event Withdraw:
    provider: indexed(address)
    value: uint256
    ts: uint256

event Supply:
    prevSupply: uint256
    supply: uint256

WEEK: constant(uint256) = 7 * 86400  # all future times are rounded by week
MAXTIME: constant(uint256) = 4 * 365 * 86400  # 4 years
MULTIPLIER: constant(uint256) = 10 ** 18

token: public(address)
supply: public(uint256)

locked: public(HashMap[address, LockedBalance])

epoch: public(uint256)
point_history: public(Point[100000000000000000000000000000])  # epoch -> unsigned point
user_point_history: public(HashMap[address, Point[1000000000]])  # user -> Point[user_epoch]
user_point_epoch: public(HashMap[address, uint256])
slope_changes: public(HashMap[uint256, int128])  # time -> signed slope change

controller: public(address)
transfersEnabled: public(bool)

name: public(String[64])
symbol: public(String[32])
version: public(String[32])
decimals: public(uint256)

future_smart_wallet_checker: public(address)
smart_wallet_checker: public(address)

admin: public(address)
future_admin: public(address)

alpha: public(decimal)  # Decay parameter for exponential model

@external
def __init__(token_addr: address, _name: String[64], _symbol: String[32], _version: String[32], _alpha: decimal):
    self.admin = msg.sender
    self.token = token_addr
    self.point_history[0].blk = block.number
    self.point_history[0].ts = block.timestamp
    self.controller = msg.sender
    self.transfersEnabled = True
    self.alpha = _alpha

    _decimals: uint256 = ERC20(token_addr).decimals()
    assert _decimals <= 255
    self.decimals = _decimals

    self.name = _name
    self.symbol = _symbol
    self.version = _version

@external
def commit_transfer_ownership(addr: address):
    assert msg.sender == self.admin  # dev: admin only
    self.future_admin = addr
    log CommitOwnership(addr)

@external
def apply_transfer_ownership():
    assert msg.sender == self.admin  # dev: admin only
    _admin: address = self.future_admin
    assert _admin != ZERO_ADDRESS  # dev: admin not set
    self.admin = _admin
    log ApplyOwnership(_admin)

@external
def commit_smart_wallet_checker(addr: address):
    assert msg.sender == self.admin
    self.future_smart_wallet_checker = addr

@external
def apply_smart_wallet_checker():
    assert msg.sender == self.admin
    self.smart_wallet_checker = self.future_smart_wallet_checker

@internal
def assert_not_contract(addr: address):
    if addr != tx.origin:
        checker: address = self.smart_wallet_checker
        if checker != ZERO_ADDRESS:
            if SmartWalletChecker(checker).check(addr):
                return
        raise "Smart contract depositors not allowed"

@external
@view
def get_last_user_slope(addr: address) -> int128:
    uepoch: uint256 = self.user_point_epoch[addr]
    return self.user_point_history[addr][uepoch].slope

@external
@view
def user_point_history__ts(_addr: address, _idx: uint256) -> uint256:
    return self.user_point_history[_addr][_idx].ts

@external
@view
def locked__end(_addr: address) -> uint256:
    return self.locked[_addr].end

@internal
def _checkpoint(addr: address, old_locked: LockedBalance, new_locked: LockedBalance):
    u_old: Point = empty(Point)
    u_new: Point = empty(Point)
    old_dslope: int128 = 0
    new_dslope: int128 = 0
    _epoch: uint256 = self.epoch

    if addr != ZERO_ADDRESS:
        # Calculate slopes and biases
        if old_locked.end > block.timestamp and old_locked.amount > 0:
            u_old.slope = old_locked.amount / MAXTIME
            u_old.bias = u_old.slope * convert(old_locked.end - block.timestamp, int128)
        if new_locked.end > block.timestamp and new_locked.amount > 0:
            T = convert(new_locked.end - block.timestamp, decimal) / convert(MAXTIME, decimal)
            u_new.slope = new_locked.amount / MAXTIME
            u_new.bias = u_new.slope * convert(1 / T ** self.alpha, int128)

        old_dslope = self.slope_changes[old_locked.end]
        if new_locked.end != 0:
            if new_locked.end == old_locked.end:
                new_dslope = old_dslope
            else:
                new_dslope = self.slope_changes[new_locked.end]

    last_point: Point = Point({bias: 0, slope: 0, ts: block.timestamp, blk: block.number})
    if _epoch > 0:
        last_point = self.point_history[_epoch]
    last_checkpoint: uint256 = last_point.ts
    initial_last_point: Point = last_point
    block_slope: uint256 = 0
    if block.timestamp > last_point.ts:
        block_slope = MULTIPLIER * (block.number - last_point.blk) / (block.timestamp - last_point.ts)
    
    t_i: uint256 = (last_checkpoint / WEEK) * WEEK
    for i in range(255):
        t_i += WEEK
        d_slope: int128 = 0
        if t_i > block.timestamp:
            t_i = block.timestamp
        else:
            d_slope = self.slope_changes[t_i]
        last_point.bias -= last_point.slope * convert(t_i - last_checkpoint, int128)
        last_point.slope += d_slope
        if last_point.bias < 0:
            last_point.bias = 0
        if last_point.slope < 0:
            last_point.slope = 0
        last_checkpoint = t_i
        last_point.ts = t_i
        last_point.blk = initial_last_point.blk + block_slope * (t_i - initial_last_point.ts) / MULTIPLIER
        _epoch += 1
        if t_i == block.timestamp:
            last_point.blk = block.number
            break
        else:
            self.point_history[_epoch] = last_point

    self.epoch = _epoch

    if addr != ZERO_ADDRESS:
        last_point.slope += (u_new.slope - u_old.slope)
        last_point.bias += (u_new.bias - u_old.bias)
        if last_point.slope < 0:
            last_point.slope = 0
        if last_point.bias < 0:
            last_point.bias = 0

    self.point_history[_epoch] = last_point

    if addr != ZERO_ADDRESS:
        if old_locked.end > block.timestamp:
            old_dslope += u_old.slope
            if new_locked.end == old_locked.end:
                old_dslope -= u_new.slope
            self.slope_changes[old_locked.end] = old_dslope

        if new_locked.end > block.timestamp:
            if new_locked.end > old_locked.end:
                new_dslope -= u_new.slope
                self.slope_changes[new_locked.end] = new_dslope

        user_epoch: uint256 = self.user_point_epoch[addr] + 1

        self.user_point_epoch[addr] = user_epoch
        u_new.ts = block.timestamp
        u_new.blk = block.number

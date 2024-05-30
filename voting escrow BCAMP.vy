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
def user_point_history__ts(_addr: address, _idx: uint256) -> uint256:
    return self.user_point_history[_addr][_idx].ts

@external
@view
def locked__end(_addr: address) -> uint256:
    return self.locked[_addr].end

@external
    def convert_to_vebcamp(amount: uint256, lock_time: uint256):
        token_balance = TokenInterface(self.token).balances(msg.sender)
        assert token_balance >= amount, "Insufficient token balance"
        assert lock_time > 0 and lock_time <= MAXTIME, "Invalid lock time"
        
        old_locked = self.user_locked_balances[msg.sender]
        new_locked = LockedBalance({
            amount: old_locked.amount + amount,
            end: block.timestamp + lock_time
        })
        
        self._checkpoint(msg.sender, old_locked, new_locked)
        
        # Calculate initial veBCAMP amount
        T = lock_time
        initial_veBCAMP = amount * MULTIPLIER / (T ** self.alpha)
        
        self.user_locked_balances[msg.sender] = new_locked
        
        TokenInterface(self.token).burn(amount)
        
        log ConvertToVeBCamp(msg.sender, amount, initial_veBCAMP)

    @external
    def checkpoint(participant: address):
        old_locked = self.user_locked_balances[participant]
        if old_locked.amount == 0 or old_locked.end <= block.timestamp:
            return  # No locked tokens or lock period has ended

        elapsed_time = block.timestamp - (old_locked.end - MAXTIME)
        remaining_time = old_locked.end - block.timestamp

        # Calculate current veBCAMP balance
        current_veBCAMP = old_locked.amount * MULTIPLIER / (MAXTIME ** self.alpha) * (1 - elapsed_time / MAXTIME)
        
        # Update locked balance to reflect the decay
        new_locked = LockedBalance({
            amount: current_veBCAMP,
            end: old_locked.end
        })
        
        self._checkpoint(participant, old_locked, new_locked)
        self.user_locked_balances[participant] = new_locked

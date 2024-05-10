from vyper.interfaces import ERC20

implements: ERC20

# Contract owner address
owner: public(address)

# Token balances
balances: public(HashMap[address, uint256])

# Allowances for tokens allowed to be spent by others
allowances: public(HashMap[address, HashMap[address, uint256]])

# Events
event Transfer:
    _from: indexed(address)
    _to: indexed(address)
    _value: uint256

event Approval:
    _owner: indexed(address)
    _spender: indexed(address)
    _value: uint256

@external
def __init__(name: string[64], symbol: string[32], initialSupply: uint256, decimals: uint256):
    self.owner = msg.sender
    self.name = name
    self.symbol = symbol
    self.decimals = decimals
    self.balances[msg.sender] = initialSupply * 10 ** decimals
    log Transfer(ZERO_ADDRESS, msg.sender, self.balances[msg.sender])

@external
def mint(to: address, amount: uint256):
    assert msg.sender == self.owner  # Only the owner can mint new tokens
    assert to != ZERO_ADDRESS, "Cannot mint to zero address"
    self.balances[to] += amount
    log Transfer(ZERO_ADDRESS, to, amount)

@external
def burn(amount: uint256):
    assert msg.sender == self.owner  # Only the owner can burn tokens
    self.balances[msg.sender] -= amount
    log Transfer(msg.sender, ZERO_ADDRESS, amount)

@external
def burn_from(account: address, amount: uint256):
    assert msg.sender == self.owner  # Only the owner can initiate burn_from
    assert account != ZERO_ADDRESS, "Cannot burn from zero address"
    assert self.allowances[account][msg.sender] >= amount, "Burn amount exceeds allowance"
    self.allowances[account][msg.sender] -= amount
    self.balances[account] -= amount
    log Transfer(account, ZERO_ADDRESS, amount)

@external
def transfer(recipient: address, amount: uint256) -> bool:
    raise "Transfers are disabled"

@external
def transfer_from(sender: address, recipient: address, amount: uint256) -> bool:
    raise "TransferFrom is disabled"
from vyper.interfaces import ERC20

implements: ERC20

# Contract owner (supplier) address
supplier: public(address)

# Token balances
balances: public(HashMap[address, uint256])

# Events
event Transfer:
    _from: indexed(address)
    _to: indexed(address)
    _value: uint256

@external
def __init__(name: String[64], symbol: String[32], initialSupply: uint256, decimals: uint256):
    self.supplier = msg.sender
    self.name = name
    self.symbol = symbol
    self.decimals = decimals
    self.balances[msg.sender] = initialSupply * 10 ** decimals
    log Transfer(ZERO_ADDRESS, msg.sender, self.balances[msg.sender])

@external
def mint(to: address, amount: uint256):
    assert msg.sender == self.supplier, "Only the supplier can mint new tokens"
    assert to != ZERO_ADDRESS, "Cannot mint to zero address"
    self.balances[to] += amount
    log Transfer(ZERO_ADDRESS, to, amount)

@external
def burn(amount: uint256):
    assert msg.sender == self.supplier, "Only the supplier can burn tokens"
    self.balances[msg.sender] -= amount
    log Transfer(msg.sender, ZERO_ADDRESS, amount)

@external
def transfer(recipient: address, amount: uint256) -> bool:
    raise "Transfers are disabled"

@external
def transfer_from(sender: address, recipient: address, amount: uint256) -> bool:
    raise "TransferFrom is disabled"
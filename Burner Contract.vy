# @version 0.2.8
"""
@title veBCAMP Burner
@notice Handles the redemption and burning of veBCAMP tokens
"""

from vyper.interfaces import ERC20

interface veBCAMPInterface:
    def redeem(_amount: uint256) -> bool: nonpayable
    def burn(_amount: uint256): nonpayable

BCAMP_TOKEN: constant(address) = 0xYourBCAMPTokenContractAddress

# State variables
owner: public(address)
emergency_owner: public(address)
is_killed: public(bool)

# Events
event RedeemAndBurn:
    sender: indexed(address)
    amount: uint256

@external
def __init__(_owner: address, _emergency_owner: address):
    """
    @notice Contract constructor
    @param _owner Owner address, has permissions to manage contract.
    @param _emergency_owner Address with emergency permissions.
    """
    self.owner = _owner
    self.emergency_owner = _emergency_owner

@external
def redeem_and_burn(_amount: uint256) -> bool:
    """
    @notice Redeems veBCAMP tokens for underlying rights and then burns the tokens.
    @param _amount The amount of veBCAMP to redeem and burn.
    @return bool indicating success.
    """
    assert not self.is_killed, "Contract is currently disabled"  # Check if the contract is active
    assert _amount > 0, "Burn amount must be greater than zero"  # Validate non-zero input
    
    # Check the caller's token balance to ensure they have enough tokens to burn
    current_balance: uint256 = veBCAMPInterface(BCAMP_TOKEN).balanceOf(msg.sender)
    assert current_balance >= _amount, "Insufficient token balance for burn"

    # Redeem the rights associated with veBCAMP tokens
    success: bool = veBCAMPInterface(BCAMP_TOKEN).redeem(_amount)
    assert success, "Redemption failed"

    # Burn veBCAMP tokens
    success = veBCAMPInterface(BCAMP_TOKEN).burn(_amount)
    assert success, "Burning of tokens failed"

    log RedeemAndBurn(msg.sender, _amount)
    return True
@external
def set_killed(_is_killed: bool) -> bool:
    """
    @notice Allows the owner or emergency owner to disable or enable the burning functionality.
    @param _is_killed True to kill, False to activate the contract.
    @return bool indicating success.
    """
    assert msg.sender in [self.owner, self.emergency_owner]
    self.is_killed = _is_killed
    return True

@external
def transfer_ownership(_new_owner: address) -> bool:
    """
    @notice Transfers ownership of the contract to a new owner.
    @param _new_owner Address of the new owner.
    @return bool indicating success.
    """
    assert msg.sender == self.owner
    self.owner = _new_owner
    return True

@external
def transfer_emergency_ownership(_new_emergency_owner: address) -> bool:
    """
    @notice Transfers emergency ownership to a new address.
    @param _new_emergency_owner Address of the new emergency owner.
    @return bool indicating success.
    """
    assert msg.sender == self.emergency_owner
    self.emergency_owner = _new_emergency_owner
    return True


# test_convert_to_vebcamp.py

import pytest
from brownie import accounts, chain, Wei, TokenInterface, VotingEscrow

@pytest.fixture
def token():
    return accounts[0].deploy(TokenInterface, "TestToken", "TTK", 1000 * 10**18, 18)

@pytest.fixture
def escrow(token):
    return accounts[0].deploy(VotingEscrow, token.address, "veBCAMP", "vBCAMP", "1.0", 0.5)

def test_convert_to_vebcamp(token, escrow):
    initial_supply = 1000 * 10**18
    user = accounts[1]
    token.transfer(user, 100 * 10**18, {'from': accounts[0]})
    token.approve(escrow.address, 100 * 10**18, {'from': user})

    amount = 100 * 10**18
    lock_time = 2 * 365 * 86400  # 2 years

    # User converts tokens to veBCAMP
    tx = escrow.convert_to_vebcamp(amount, lock_time, {'from': user})

    # Check the user's locked balance
    locked_balance = escrow.locked(user)
    assert locked_balance.amount == amount
    assert locked_balance.end == chain.time() + lock_time

    # Check the event log
    initial_veBCAMP = amount * 10**18 / (lock_time ** 0.5)
    assert tx.events['ConvertToVeBCamp']['provider'] == user
    assert tx.events['ConvertToVeBCamp']['value'] == amount
    assert pytest.approx(tx.events['ConvertToVeBCamp']['veBCAMP'], rel=1e-5) == initial_veBCAMP

    # Check the token balance after conversion
    assert token.balanceOf(user) == 0
    assert token.balanceOf(escrow.address) == 0  # Assuming tokens are burned

    # Simulate passage of time and check veBCAMP decay
    chain.sleep(365 * 86400)  # Fast forward 1 year
    chain.mine()

    escrow.checkpoint(user)
    elapsed_time = 1 * 365 * 86400
    remaining_time = lock_time - elapsed_time
    current_veBCAMP = amount * 10**18 / (lock_time ** 0.5) * (1 - elapsed_time / lock_time)
    locked_balance = escrow.locked(user)
    assert pytest.approx(locked_balance.amount, rel=1e-5) == current_veBCAMP

    # Check the updated veBCAMP value after 1 year
    expected_veBCAMP = amount * 10**18 / (lock_time ** 0.5) * (1 - elapsed_time / lock_time)
    assert pytest.approx(locked_balance.amount, rel=1e-5) == expected_veBCAMP

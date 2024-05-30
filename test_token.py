# test_token.py

import pytest
from brownie import accounts, Token

@pytest.fixture
def token():
    return accounts[0].deploy(Token, "TestToken", "TTK", 1000, 18)

def test_initial_supply(token):
    # Test initial supply
    assert token.balances(accounts[0]) == 1000 * 10 ** 18

def test_mint(token):
    # Minting should only be allowed by the owner
    token.mint(accounts[1], 500 * 10 ** 18, {'from': accounts[0]})
    assert token.balances(accounts[1]) == 500 * 10 ** 18

    with pytest.raises(Exception):
        token.mint(accounts[2], 500 * 10 ** 18, {'from': accounts[1]})  # Should raise an exception

def test_burn(token):
    # Burning should only be allowed by the owner
    token.burn(200 * 10 ** 18, {'from': accounts[0]})
    assert token.balances(accounts[0]) == 800 * 10 ** 18

    with pytest.raises(Exception):
        token.burn(100 * 10 ** 18, {'from': accounts[1]})  # Should raise an exception

def test_burn_from(token):
    # Allow account 1 to burn 200 tokens from account 0
    token.approve(accounts[1], 200 * 10 ** 18, {'from': accounts[0]})
    token.burn_from(accounts[0], 200 * 10 ** 18, {'from': accounts[0]})
    assert token.balances(accounts[0]) == 800 * 10 ** 18

    # Attempting to burn more than the allowance should fail
    token.approve(accounts[1], 100 * 10 ** 18, {'from': accounts[0]})
    with pytest.raises(Exception):
        token.burn_from(accounts[0], 200 * 10 ** 18, {'from': accounts[1]})  # Should raise an exception

def test_transfers_disabled(token):
    # Transfers should be disabled
    with pytest.raises(Exception):
        token.transfer(accounts[1], 100 * 10 ** 18, {'from': accounts[0]})

    with pytest.raises(Exception):
        token.transfer_from(accounts[0], accounts[1], 100 * 10 ** 18, {'from': accounts[1]})

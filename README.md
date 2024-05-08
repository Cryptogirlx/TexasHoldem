# TexasHoldem Smart Contract Documentation

This Solidity smart contract implements a simplified version of Texas Hold'em poker variant, where only two players play. Players can register, create tables, join tables, and take actions such as calling, raising, checking, or folding during betting rounds. The contract also handles opening and closing rounds, determining winners, and transferring rewards.
The contract owner acts as the dealer each round, the cards are represented as ERC1155 NFT tokens and to ensure real randomization it inherits from Chainlink's VRF to get random numbers that are used as tokenIDs whenever cards are dealt.

## Contract Details

Version: 0.8.20
License: MIT

## External Contracts Used

IERC20: Interface for ERC20 tokens.
Ownable: Contract to provide ownership functionality.
IERC1155: Interface for ERC1155 tokens.
VRFConsumerBaseV2: Chainlink contract for consuming verifiable random functions (VRF).
VRFCoordinatorV2Interface: Chainlink contract interface for VRF coordinator.

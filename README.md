# TexasHoldem Smart Contract Documentation

This Solidity smart contract implements a simplified version of Texas Hold'em poker variant, where only two players play. Players can register, create tables, join tables, and take actions such as calling, raising, checking, or folding during betting rounds. The contract also handles opening and closing rounds, determining winners, and transferring rewards.
The contract owner acts as the dealer each round, the cards are represented as ERC1155 NFT tokens and to ensure real randomization it inherits from Chainlink's VRF to get random numbers that are used as tokenIDs whenever cards are dealt.

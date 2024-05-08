// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

contract TexasHoldem is Ownable, VRFConsumerBaseV2 {

// -------------------------------------------------------------
// STORAGE
// -------------------------------------------------------------

uint public playerCount;
uint public tableCount;


enum TableState {
        Active,
        Inactive
    }  

struct Player {
    address wallet; // players wallet
    uint8[] cards; // tokenIDs of player's cards
    bool isActivePlayer;
    bool isBlacklisted;
}

enum PlayerAction {
        Call,
        Raise,
        Check,
        Fold
    }

struct Table {
        TableState state;
        uint buyInAmount;
        uint totalAmountinPot; 
        uint maxPlayers;
        uint[] players; // playerIDs of players
        uint8[] cardsOnTable; // tokenIDs of community cards
        bool isActive;
        address pot;
        address winner;
        IERC20 token; // the token to be used to play in the table
        IERC1155 cardsAddress; // address of the cards NFT contract
    }

    struct Round {
        bool state; // state of the round, if this is active or not
        uint8[] players; // playersIDs still playing in the round who have not folded
    }

mapping(uint => Player) public players;
mapping(uint => Table) public tables;
// player address => bool
mapping(address => bool) public balcklistedAddress;
// tableId => roundNum => Round
mapping(uint => mapping(uint => Round)) public rounds;

// ** CHAINLINK ** //

 struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }

    // Your subscription ID.
    uint64 immutable s_subscriptionId;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // Goerli 30 gwei Key Hash
    bytes32 immutable keyHash;

    // Have to calculate something in callback function so set it 1M
    uint32 callbackGasLimit = 1_000_000;

    uint16 requestConfirmations = 3;

    uint32 numWords = 4;
    
    // requestID => requestStatus
    mapping(uint256 => RequestStatus) public s_requests;
    VRFCoordinatorV2Interface immutable COORDINATOR;

// -------------------------------------------------------------
// ERRORS
// -------------------------------------------------------------
  
   error OnlyActivePlayer(string message);
   error AddressBlacklisted(string message);
   error PlayerNotDealer(string message);
   error TableAlreadyClosed(uint tableID);
   error BidTooLow(string message);
   error NoMorePlayers(string message);
   error OnlyRegisteredPlayer(string message);

// -------------------------------------------------------------
// EVENTS
// -------------------------------------------------------------

   event PlayerCreated(uint playerID);
   event TableCreated(uint tableID);
   event TableClosed(address winner, uint amountWon);
   event PlayerBlacklisted(address wallet);
   event RoundOpened(uint tableID,uint roundCount);
   event PlayerCalled(uint playerID);
   event PlayerRaised(uint playerID);
   event PlayerChecked(uint playerID);
   event PlayerFolded(uint playerID);
   event RewardsTransferred(address player,uint amount);

// -------------------------------------------------------------
// MODIFIERS
// -------------------------------------------------------------

modifier onlyActivePlayer(uint playerID){
    if(!players[playerID].isActivePlayer) revert OnlyActivePlayer("this player is inactive in this round");
    _;
}

// -------------------------------------------------------------
// CONSTRUCTOR
// -------------------------------------------------------------

constructor(address initialOwner, address _coordinatorAddress,uint64 _subscriptionId,bytes32 _keyHash) Ownable(initialOwner) VRFConsumerBaseV2(_coordinatorAddress) {
     COORDINATOR = VRFCoordinatorV2Interface(_coordinatorAddress);
        s_subscriptionId = _subscriptionId;
        keyHash = _keyHash;
}
    

// -------------------------------------------------------------
// STATE-MODIFYING FUNCTIONS
// -------------------------------------------------------------

function createTable(TableState _state,uint _buyInAmount, uint _maxPlayers,uint[] memory playerIDs, address _tokenAddress, address _pot, address _cardsAddress) external onlyOwner returns(uint) {
    // creates a table with an ID
    unchecked {
      tableCount++;
    }
     
    tables[tableCount].state = TableState.Active;
    tables[tableCount].buyInAmount = _buyInAmount;
    tables[tableCount].maxPlayers = _maxPlayers;
    tables[tableCount].pot = _pot;
    tables[tableCount].token = IERC20(_tokenAddress);
    tables[tableCount].cardsAddress = IERC1155(_cardsAddress);

    emit TableCreated(tableCount);

    return tableCount;
}

function createPlayer(address _wallet, uint tableID) external returns(uint) {
    // registers a player at a table with an ID
    uint[] memory playerArray = tables[tableID].players;
    if (balcklistedAddress[_wallet]) revert AddressBlacklisted("can't register this address");
    if (playerArray.length > tables[tableID].maxPlayers) revert NoMorePlayers("table reached max players");
    if(tables[tableID].state == TableState.Inactive) revert TableAlreadyClosed(tableID);

    unchecked {
      playerCount++;
    }
    
    players[playerCount].wallet = _wallet;
    players[playerCount].isActivePlayer = true;
 
    // add player to table
    tables[tableID].players.push(playerCount);

   emit PlayerCreated(playerCount);
}

address[] playerAddresses; // declaing storage variable for the function below

// function openRound(uint tableID, uint playerID) external onlyOwner {
//     // opens a new round in a game

//     uint roundCount;

//     unchecked {
//         roundCount++;
//     }
    
//     if(roundCount == 1) {
//             //taking initial bets

//     uint[] memory playerIDs = tables[tableID].players;

//     // TODO
//     for (uint i = 0; i < playerIDs.length; i++) { 
         
//         playerAddresses.push(players[playerIDs[i]].wallet);
//          for (uint j = 0; i < playerAddresses.length; j++) {
//             IERC20(tables[tableID].token).transferFrom(playerAddresses[i],tables[tableID].pot,tables[tableID].buyInAmount);
//          }
//     }

//     // set totalAmountInPot 

//     uint potBalance = IERC20(tables[tableID].token).balanceOf(tables[tableID].pot);
//     tables[tableID].totalAmountinPot = potBalance;

//     // deal cards to players and place community cards on the table
//     _dealCards();
//     _dealCommunityCards();
//     }

//     if (roundCount > 1) {
//       _addCommunityCard();
//     }

//     emit RoundOpened(tableID,roundCount);

// }

// function playerAction(PlayerAction action, uint raiseAmount, uint tableID, uint playerID) external onlyActivePlayer(playerID) {
//     if(msg.sender != players[playerID].wallet) revert OnlyRegisteredPlayer("");

//     if (action == PlayerAction.Call) {
//     // player puts the amount to what's in the pot already
    
//     // update totalAmountinPot
//         uint currentAmount = tables[tableID].totalAmountinPot;
//         uint newAmount = currentAmount * 2 ;
//         currentAmount = newAmount;

//     // trasfer funds to pot
//       IERC20(tables[tableID].token).transferFrom(players[playerID].wallet,tables[tableID].pot,tables[tableID].totalAmountinPot);
//        emit PlayerCalled(playerID);
       
//     }

//     if (action == PlayerAction.Raise) {
//     // player raises the last highest chip
//     if(raiseAmount < tables[tableID].totalAmountinPot) revert BidTooLow("insufficient bid");
      
//       // update bets in pot
//         uint currentAmount = tables[tableID].totalAmountinPot;
//         uint newAmount = currentAmount + raiseAmount;
//         currentAmount = newAmount;
     
//      // transfer funds
//         IERC20(tables[tableID].token).transferFrom(players[playerID].wallet,tables[tableID].pot,raiseAmount);
//         emit PlayerRaised(playerID);
        
//     }

//     if (action == PlayerAction.Check) {
//     // player does nothing
//         emit PlayerChecked(playerID);
//     }

//     if (action == PlayerAction.Fold) {
//     // player reveals cards and gets removed from active players

//         // TODO revealCards();

//         // set player to inactive
//         players[playerID].isActivePlayer = false;
//         emit PlayerFolded(playerID);
//     }
// }

// function showdown(uint tableID) external onlyOwner {
//     // all active players reveal their cards

//      uint[] memory playerIDs = tables[tableID].players;
//      for (uint i = 0; i < playerIDs.length; i++) {
//         // TODO revealCards(palyerIDs[i]);
//      }
   
//     uint playerID;
//    // = determineWinner(); TODO - return playerID via this function
//    _closeTable(tableID,playerID);
// }

// function determineWinner(uint tableID) external onlyOwner returns (uint){
//     // TODO function that determins the winner and returns playerID
// }

// function blacklistPlayer(uint playerID) external onlyOwner{
//     // blacklists a malicious player

//     address playerAddress = players[playerID].wallet;
//     if (balcklistedAddress[playerAddress]) revert AddressBlacklisted("address already blacklisted");

//     players[playerID].isBlacklisted = true;
    
//     balcklistedAddress[playerAddress] = true;

//     emit PlayerBlacklisted(players[playerID].wallet);
// }

// // -------------------------------------------------------------
// // INTERNAL FUNCTIONS
// // -------------------------------------------------------------

//    function _dealCards() internal {
//     // TODO
//     // assuming that the cards are NFTs we can integrate Chainlink's VFR function and deal random tokenIDs to each player and send it to their wallet
//     // we would save the corresponding 
//    }

//    function _dealCommunityCards() internal {
//     // TODO
//     // assuming that the cards are NFTs we can integrate Chainlink's VFR function deal random cards by a random tokenID to the table
//    }

//    function _addCommunityCard() internal {
//     // TODO
//     // assuming that the cards are NFTs we can integrate Chainlink's VFR function and deal a random card by a random tokenID to the table
//    }

//    function _revealCards(uint playerID) internal view returns (uint8[] memory cards) {
//     return players[playerID].cards;
//    }

//    function _closeTable(uint tableID,uint playerID) internal {
//     if (tables[tableID].state == TableState.Inactive) revert TableAlreadyClosed(tableID);

//     // close the table
//     tables[tableID].state = TableState.Inactive;
//     tables[tableID].winner = players[playerID].wallet;

//     // reset all players to active
//     uint[] memory playerIDs = tables[tableID].players;
//     for (uint i = 0; i < playerIDs.length; i++) { 
//         _setPlayerToActive(playerIDs[i]);
//     }

//      // TODO send cards back to dealer wallet

//     // for (uint i = 0; i < playerIDs.length; i++) { 
//     //     IERC1155(tables[tableID].cardsAddress).transferFrom(playerWallets[i],address(this),tokenIDs[i]);
//     // }
    
//     _sendWinnerRewards(tableID,playerID,tables[tableID].totalAmountinPot);
//     emit TableClosed(tables[tableID].winner,tables[tableID].totalAmountinPot);
// }

// function _sendWinnerRewards(uint tableID,uint playerID, uint amount) internal {

//      // set totalAmountInPot to 0

//      tables[tableID].totalAmountinPot = 0;

//      IERC20(tables[tableID].token).transferFrom(players[playerID].wallet,tables[tableID].pot,amount);

//      emit RewardsTransferred(players[playerID].wallet,amount);
// }

// function _setPlayerToActive(uint playerID) internal {
//     players[playerID].isActivePlayer = true;
// }

// // -------------------------------------------------------------
// // CHAINLINK
// // -------------------------------------------------------------

// function fulfillRandomWords(
//         uint256 _requestId,
//         uint256[] memory _randomWords
//     ) internal override {
//         // TODO function to get the random numbers
//     }

//       function getRequestStatus(uint256 _requestId)
//         external
//         view
//         returns (bool fulfilled, uint256[] memory randomWords)
//     {
//         require(s_requests[_requestId].exists, "request not found");
//         RequestStatus memory request = s_requests[_requestId];
//         return (request.fulfilled, request.randomWords);
//     }

}
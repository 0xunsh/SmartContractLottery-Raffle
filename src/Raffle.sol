// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

/**
 * @title A sample Raffle Contract
 * @dev Implements Chainlink VRFv2.5
 * @author Ansh Agrawal
 * @notice This contract is for learning purposes only.
 */

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    /* error messages */
    error Raffle__sendMoreEthToEnterRafel();
    error Raffle_TransactionFailed();
    error Raffle__UpKeepNotNeeded(uint256 balance, uint256 players, uint256 raffleState);

    /* type declarations */
    enum RaffleState{
        OPEN,
        CALCULATING
    }

    /* state variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entryFee;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimestamp;
    address private s_recentWinner;
    RaffleState private s_RaffleState;

    /* events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    /*s_vrfCoordinator is an interface instance used to interact with 
    a deployed contract at _vrfCoordinator that implements the IVRFCoordinatorV2Plus interface. 
    This design allows the contract to call functions on s_vrfCoordinator as defined by the interface, 
    providing a flexible and decoupled way to interact with other contracts.*/

    constructor(
        uint256 entryFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        uint256 subscriptionId 
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entryFee = entryFee;
        i_interval = interval;
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimestamp = block.timestamp;
        s_RaffleState = RaffleState.OPEN;
    }

    function enterRaffel() external payable {
        if (msg.value < i_entryFee) {
            revert Raffle__sendMoreEthToEnterRafel();
        }

        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    // getting a random number
    // choosing a randomy player using that random number
    // returing that player

    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) 
    {
        bool timeHasPassed = block.timestamp - s_lastTimestamp > i_interval;
        bool enoughPlayers = s_players.length > 0;
        bool enoughETH = address(this).balance > 0;
        bool isOpen = s_RaffleState == RaffleState.OPEN;
        upkeepNeeded = timeHasPassed && enoughPlayers && enoughETH && isOpen;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded,) = checkUpkeep("");

        if(!upkeepNeeded) {
            revert Raffle__UpKeepNotNeeded(address(this).balance, s_players.length, uint256(s_RaffleState));
        }
    
        s_RaffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        s_vrfCoordinator.requestRandomWords(request);
    }

    function getEntryFee() external view returns (uint256) {
        return i_entryFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_RaffleState;
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal override {

        /* Checks */

        /* Effects */
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_RaffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        /* Interactions */
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle_TransactionFailed();
        }
        
    }
}

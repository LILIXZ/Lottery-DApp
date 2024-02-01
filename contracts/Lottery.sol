// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

abstract contract VRFConsumerBaseV2 {
  error OnlyCoordinatorCanFulfill(address have, address want);
  address private immutable vrfCoordinator;

  /**
   * @param _vrfCoordinator address of VRFCoordinator contract
   */
  constructor(address _vrfCoordinator) {
    vrfCoordinator = _vrfCoordinator;
  }

  /**
   * @notice fulfillRandomness handles the VRF response. Your contract must
   * @notice implement it. See "SECURITY CONSIDERATIONS" above for important
   * @notice principles to keep in mind when implementing your fulfillRandomness
   * @notice method.
   *
   * @dev VRFConsumerBaseV2 expects its subcontracts to have a method with this
   * @dev signature, and will call it once it has verified the proof
   * @dev associated with the randomness. (It is triggered via a call to
   * @dev rawFulfillRandomness, below.)
   *
   * @param requestId The Id initially returned by requestRandomness
   * @param randomWords the VRF output expanded to the requested number of words
   */
  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal virtual;

  // rawFulfillRandomness is called by VRFCoordinator when it receives a valid VRF
  // proof. rawFulfillRandomness then calls fulfillRandomness, after validating
  // the origin of the call
  function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
    if (msg.sender != vrfCoordinator) {
      revert OnlyCoordinatorCanFulfill(msg.sender, vrfCoordinator);
    }
    fulfillRandomWords(requestId, randomWords);
  }
}


interface VRFCoordinatorV2Interface {
  /**
   * @notice Get configuration relevant for making requests
   * @return minimumRequestConfirmations global min for request confirmations
   * @return maxGasLimit global max for request gas limit
   * @return s_provingKeyHashes list of registered key hashes
   */
  function getRequestConfig() external view returns (uint16, uint32, bytes32[] memory);

  /**
   * @notice Request a set of random words.
   * @param keyHash - Corresponds to a particular oracle job which uses
   * that key for generating the VRF proof. Different keyHash's have different gas price
   * ceilings, so you can select a specific one to bound your maximum per request cost.
   * @param subId  - The ID of the VRF subscription. Must be funded
   * with the minimum subscription balance required for the selected keyHash.
   * @param minimumRequestConfirmations - How many blocks you'd like the
   * oracle to wait before responding to the request. See SECURITY CONSIDERATIONS
   * for why you may want to request more. The acceptable range is
   * [minimumRequestBlockConfirmations, 200].
   * @param callbackGasLimit - How much gas you'd like to receive in your
   * fulfillRandomWords callback. Note that gasleft() inside fulfillRandomWords
   * may be slightly less than this amount because of gas used calling the function
   * (argument decoding etc.), so you may need to request slightly more than you expect
   * to have inside fulfillRandomWords. The acceptable range is
   * [0, maxGasLimit]
   * @param numWords - The number of uint256 random values you'd like to receive
   * in your fulfillRandomWords callback. Note these numbers are expanded in a
   * secure way by the VRFCoordinator from a single random value supplied by the oracle.
   * @return requestId - A unique identifier of the request. Can be used to match
   * a request to a response in fulfillRandomWords.
   */
  function requestRandomWords(
    bytes32 keyHash,
    uint64 subId,
    uint16 minimumRequestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
  ) external returns (uint256 requestId);

  /**
   * @notice Create a VRF subscription.
   * @return subId - A unique subscription id.
   * @dev You can manage the consumer set dynamically with addConsumer/removeConsumer.
   * @dev Note to fund the subscription, use transferAndCall. For example
   * @dev  LINKTOKEN.transferAndCall(
   * @dev    address(COORDINATOR),
   * @dev    amount,
   * @dev    abi.encode(subId));
   */
  function createSubscription() external returns (uint64 subId);

  /**
   * @notice Get a VRF subscription.
   * @param subId - ID of the subscription
   * @return balance - LINK balance of the subscription in juels.
   * @return reqCount - number of requests for this subscription, determines fee tier.
   * @return owner - owner of the subscription.
   * @return consumers - list of consumer address which are able to use this subscription.
   */
  function getSubscription(
    uint64 subId
  ) external view returns (uint96 balance, uint64 reqCount, address owner, address[] memory consumers);

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @param newOwner - proposed new owner of the subscription
   */
  function requestSubscriptionOwnerTransfer(uint64 subId, address newOwner) external;

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @dev will revert if original owner of subId has
   * not requested that msg.sender become the new owner.
   */
  function acceptSubscriptionOwnerTransfer(uint64 subId) external;

  /**
   * @notice Add a consumer to a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - New consumer which can use the subscription
   */
  function addConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Remove a consumer from a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - Consumer to remove from the subscription
   */
  function removeConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Cancel a subscription
   * @param subId - ID of the subscription
   * @param to - Where to send the remaining LINK to
   */
  function cancelSubscription(uint64 subId, address to) external;

  /*
   * @notice Check to see if there exists a request commitment consumers
   * for all consumers and keyhashes for a given sub.
   * @param subId - ID of the subscription
   * @return true if there exists at least one unfulfilled request for the subscription, false
   * otherwise.
   */
  function pendingRequestExists(uint64 subId) external view returns (bool);
}


contract VRFConsumer is VRFConsumerBaseV2 {
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */
    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 keyHash =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 300000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 5;

    // setup contract owner address
    address contractOwner;    

    // modifier function
    modifier onlyOwner {
        require(msg.sender == contractOwner);
        _;
    }

    // constructor - setup the subscription id and contract owner
    constructor(
        uint64 _subscriptionId
    ) VRFConsumerBaseV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625) {
        contractOwner = msg.sender;
        
        COORDINATOR = VRFCoordinatorV2Interface(
            0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
        );
        s_subscriptionId = _subscriptionId;
    }

    // subscribe and request
    function requestRandomWords() external onlyOwner returns(uint256 requestId) {
        // getting request id
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        // record new request status
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });

        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);

        return requestId;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords)
        internal
        override
    {
        //在此添加 solidity 代码
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].randomWords = _randomWords;
        s_requests[_requestId].fulfilled  = true;
        emit RequestFulfilled(_requestId, _randomWords);
    }

     function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }
}

contract Lottery {
	//struct used to store the user information
	struct User {
		address userAddress;
		uint tokensBought;
    uint[] guess;
	}

	// a list of the users
	mapping (address => User) public users;

  // mapping guess list
  bytes32[] public guessCandidates;

  address[] public userAddresses;

	address payable public owner;
	bytes32 winningGuessSha3;

  VRFConsumer generator;

	//contructor function
	constructor(address _randomNumberGenerator) {
		// by default the owner of the contract is accounts[0] to set the owner change truffle.js
		owner = payable(msg.sender);
    generator = VRFConsumer(_randomNumberGenerator);
    uint256 lastRequestId = generator.lastRequestId();
    (, uint256[] memory randomWords) = generator.getRequestStatus(lastRequestId);
		winningGuessSha3 = keccak256(abi.encode(randomWords[0] % 10 + 1));
    for (uint i = 0; i < randomWords.length - 1; i++){
      guessCandidates.push(keccak256(abi.encode(randomWords[i+1] % 10 + 1)));
    }
	}

  // returns the number of tokens purchased by an account
  function userTokens(address _user) view public returns (uint) {
    return users[_user].tokensBought;
  }

  // returns the guess made by user so far
  function userGuesses(address _user) view public returns(uint[] memory) {
    return users[_user].guess;
  }

  // returns the winning guess
  function winningGuess() view public returns(bytes32) {
    return winningGuessSha3;
  }

  // to add a new user to the contract to make guesses
  function makeUser() public{
    users[msg.sender].userAddress = msg.sender;
    users[msg.sender].tokensBought = 0;
    userAddresses.push(msg.sender);
  }

	// function to add tokens to the user that calls the contract
  // the money held in contract is sent using a payable modifier function
  // money can be released using selfdestruct(address)
	function addTokens() public payable {
    uint present = 0;
    uint tokensToAdd = ((msg.value * 100 / 2) /(10**18));

    for(uint i = 0; i < userAddresses.length; i++) {
      if(userAddresses[i] == msg.sender) {
        present = 1;
        break;
      }
    }

    // adding tokens if the user present in the userAddresses array
    if (present == 1) {
      users[msg.sender].tokensBought += tokensToAdd;
    }
	}

	// to add user guesses
	function makeGuess(uint _userGuess) public {
    require(_userGuess < 10 && users[msg.sender].tokensBought > 0);
    users[msg.sender].guess.push(_userGuess);
    users[msg.sender].tokensBought--;
	}

	// doesn't allow anyone to buy anymore tokens
	function closeGame() public view returns(address) {
    // can only be called my the owner of the contract
		require(owner == msg.sender, "Only owner can close the game.");
    return winnerAddress();
	}

	// returns the address of the winner once the game is closed
	function winnerAddress() public view returns(address payable) {
    for(uint i = 0; i < userAddresses.length; i++) {
      User memory user= users[userAddresses[i]];

      for(uint j = 0; j < user.guess.length; j++) {
        if (keccak256(abi.encode(user.guess[j])) == winningGuessSha3) {
          return payable(user.userAddress);
        }
      }
    }
    // the owner wins if there are no winning guesses
    return owner;
	}

	// sends 50% of the ETH in contract to the winner and rest of it to the owner
	function getPrice() public returns (uint) {
    require(owner == msg.sender);
    address payable winner = winnerAddress();
    if (winner == owner) {
      owner.transfer(address(this).balance);
    } else {
      // returns the half the balance of the contract
      uint toTransfer = address(this).balance / 2;

      // transfer 50% to the winner
      winner.transfer(toTransfer);
      // transfer rest of the balance to the owner of the contract
      owner.transfer(address(this).balance);

    }
    // Reset guess
    resetGuesses();

    // Reset winning guesses
    resetWinningGuess();
    return address(this).balance;
	}

  function reimburseTokens() public {
    require(owner == msg.sender, "Only owner can reimburse tokens.");

    // Looping through users mapping, get all the unused tokens
    for(uint i = 0; i < userAddresses.length; i++){
      address userAddress = userAddresses[i];
      uint unusedTokens = users[userAddress].tokensBought;
      User storage _user =  users[userAddress];
      
      if (unusedTokens > 0){
        // If unused tokens > 0, update unused tokens to 0
        _user.tokensBought = 0; 
        // Transfer ethers of unused tokens to the users
        payable(userAddress).transfer((unusedTokens* (10**18)) * 2 / 100);
      }
    }
  }

  function resetGuesses() private {
    for(uint i = 0; i < userAddresses.length; i++) {
        address userAddress = userAddresses[i];
        users[userAddress].guess = new uint[](0); // Clear the guess array
    }
  }

  function resetWinningGuess() private {
    if (guessCandidates.length > 0) {
      winningGuessSha3 = guessCandidates[0];
      delete guessCandidates[0];
    } else {
      uint256 lastRequestId = generator.lastRequestId();
      (, uint256[] memory randomWords) = generator.getRequestStatus(lastRequestId);
      winningGuessSha3 = keccak256(abi.encode(randomWords[0] % 10 + 1));
      for (uint i = 0; i < randomWords.length - 1; i++){
        guessCandidates.push(keccak256(abi.encode(randomWords[i+1] % 10 + 1)));
      }
    }
  }
}

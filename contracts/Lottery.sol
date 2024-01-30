// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
//the pragma line is the preprocessor directive, tells the version of solidity compiler

import "docs.chain.link/samples/VRF/VRFv2Consumer.sol";

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
    uint tokensToAdd = (msg.value/(10**18)) * 2 / 100;

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
    require(_userGuess < 1000000 && users[msg.sender].tokensBought > 0);
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
    return address(this).balance;
	}

  function reimburseTokens() public {
    // Looping through users mapping, get all the unused tokens
    for(uint i = 0; i < userAddresses.length; i++){
      address userAddress = userAddresses[i];
      uint unusedTokens = users[userAddress].tokensBought;
      User storage _user =  users[userAddress];
      
      if (unusedTokens > 0){
        // If unused tokens > 0, update unused tokens to 0
        _user.tokensBought = 0; 
        // Transfer ethers of unused tokens to the users
        payable(userAddress).transfer((unusedTokens * (10**18) * 2)/100);
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
    }
  }
}

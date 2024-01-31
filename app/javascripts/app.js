// import the page's CSS. Webpack will know what to do with it.
import "../stylesheets/app.css";

// import libraries we need.
import web3 from "./web3";
import lottery from "./lottery";

// lottery is our usable abstraction, which we'll use through the code below.
var owner;

// to buy more tokens, each token costs 0.02 ether
window.buyTokens = async function() {
  try{
    const accounts = await web3.eth.getAccounts();

    var token_amount = $('#token-amount').val();
    await lottery.methods.addTokens().send({
      from: accounts[0],
      value: web3.toWei(token_amount * 0.02, 'ether')
    }).then(() => {
      populateAccount();
    });

    console.log("You have been entered!")

    $('#token-amount').val('');
  } catch (error){
    console.error("Error buying tokens:", error);
    alert("Error buying tokens:", error);
  }
  return false;
}

// To make a guess, 1 guess = 1 token
window.makeGuess = async function() {
  const accounts = await web3.eth.getAccounts();

  var guess = $('#user-guess').val();
  if (Number(guess) < 1 || Number(guess) > 10 || !Number.isInteger(Number(guess))) {
    alert("Please enter a number between 1 to 10.");
    return false;
  }

  await lottery.methods.makeGuess(guess).send({
    from: accounts[0]
  }).then(()=>{
    populateAccount();
  });

  console.log("Your guess number ", guess, "is received!");

  $('#user-guess').val('');
  return false;
}

window.closeGame = async function() {
  const accounts = await web3.eth.getAccounts();
  await lottery.methods.reimburseTokens().send({
    from: accounts[0],
    gas: 140000
  });

  await lottery.methods.closeGame().call({
    from: accounts[0],
    gas: 140000
  }).then(() => {
    $('#token-amount-btn').attr('disabled', 'disabled');
    $('#user-guess-btn').attr('disabled', 'disabled');
    showEndGame();
  });
  return false;
}

window.transferFunds = async function() {
  const accounts = await web3.eth.getAccounts();

  await lottery.methods.getPrice().send({
    from: accounts[0],
    gas: 140000
  }).then(() => {
    $('#close-game-btn').attr('disabled', 'disabled');
    $('#transfer-funds-btn').attr('disabled', 'disabled');
    populateAccount();
  })
}

var showEndGame = async function() {
  $('.close-game-btn').toggleClass('display-none');
  $('.winner-info').toggleClass('display-none');

  await lottery.methods.winningGuess().call().then(function(result) {
    $('#winning-guess').html(result);
  })
  
  await lottery.methods.winnerAddress().call().then(function(result) {
    $('#winner-address').html(result);
  })
}

var populateAccount = async function () {
  const accounts = await web3.eth.getAccounts();

  // Update number of tokens user bought
  await lottery.methods.userTokens().call(accounts[0]).then(function(r){
    $('#user-tokens').html(r.toNumber());
  });

  // Update current user balance
  await web3.eth.getBalance(accounts[0], function(err, res){
    $('#user-balance').html(web3.fromWei(res.toNumber(), 'ether') + ' ether');
  });

  // Update contract balance
  await web3.eth.getBalance(lottery.options.address, function(err, res){
    $('#contract-balance').html(web3.fromWei(res.toNumber(), 'ether') + ' ether');
  });

  // Update current user's guess list
  await lottery.methods.userGuesses().call(accounts[0]).then(function(guesses){
    for(var i = 0; i < guesses.length; i++) {
      guesses_string += (guesses[i] + ",");
    }

    $('#user-guesses').html(guesses_string.substr(0, guesses_string.length - 1));
  });
}

$( document ).ready(function() {
  // set the web3 provider if not present
  if (typeof web3 !== 'undefined') {
    console.warn("Using web3 detected from external source like Metamask")
    window.web3 = new Web3(web3.currentProvider);
  } else {
    console.warn("No web3 detected. Falling back to http://localhost:8545. You should remove this fallback when you deploy live, as it's inherently insecure. Consider switching to Metamask for development. More info here: http://truffleframework.com/tutorials/truffle-and-metamask");
    window.web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:7545"));
  }

  // Lottery.setProvider(web3.currentProvider);

  // total accounts
  // window.accounts = web3.eth.getAccounts();
  // account used for making guesses and buying tokens
  // window.account = web3.eth.getAccounts()[0];

  var account =  web3.eth.getAccounts()[0];
  $('#user-account').html(account);

  lottery.methods.owner().call().then(function(result){
    owner = result;
    $('#contract-owner').html(owner);
  })

  lottery.methods.owner.call().then(function(result) {
    owner = result;
    $('#contract-owner').html(owner)
  });

  populateAccount();

});

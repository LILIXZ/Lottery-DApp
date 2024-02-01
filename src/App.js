import React from "react";
import web3 from "./web3";
import lottery from "./lottery";
import "./App.css";

const userLogo = require('./images/user.jpeg');
const etherLogo = require('./images/ether.png');
const bgLogo = require('./images/bg1.jpeg');
const winLogo = require('./images/win.jpg');

class App extends React.Component {
  state = {
    owner: "",
    player: "",
    contractBalance: 0,
    playerBalance: 0,
    playerTokenNums: 0,
    showCloseGameInfo: false,
    userGuesses: "",
  };

  async componentDidMount() {
    const owner = await lottery.methods.owner().call();
    await new Promise((resolve) => {
      web3.eth.getAccounts().then((res) => {
        this.setState(
          {
            owner: owner, 
            player: res[0] 
          }, resolve);
      })
    })

    // if current user is not participating the game, add user into the participants
    const result = await lottery.methods.users(this.state.player).call();
    if(result[0] == "0x0000000000000000000000000000000000000000"){
      await lottery.methods.makeUser().send({
        gas: 140000, 
        from: this.state.player
      });
    }

    // populate account
    await lottery.methods.userTokens(this.state.player).call().then((r) => {
      this.setState({playerTokenNums: Number(r)});
    });
    await web3.eth.getBalance(this.state.player).then((res)=>{
      this.setState({playerBalance: web3.utils.fromWei(res, 'ether') + ' ether'});
    })
    
    await web3.eth.getBalance(lottery.options.address).then((res)=>{
      this.setState({contractBalance: web3.utils.fromWei(res, 'ether') + ' ether'});
    })
    var guesses_string = "";
    await lottery.methods.userGuesses(this.state.player).call().then((guesses) => {
      for(var i = 0; i < guesses.length; i++) {
        guesses_string += (guesses[i] + ",");
      }
      this.setState({userGuesses: guesses_string.substr(0, guesses_string.length - 1)});
    });

  }

  render() {
    return (
      <>
        <header className="artistic-text">
          Lottery
        </header>
        <div className="big">
          {!this.state.showCloseGameInfo ? (
            <>
            <div className="small1">
              <h2 className="artistic-text3">User</h2>
              <div className="tupian">
                <img src={userLogo} className="img-responsive" alt="User" />
              </div>
              <ul className="ull">
                <li><i>Account:&nbsp;<span id="user-account">{this.state.player}</span></i></li>
                <li><i>Balance:&nbsp;<span id="user-balance">{this.state.playerBalance}</span></i></li>
                <li><i>Total tokens:&nbsp;<span id="user-tokens">{this.state.playerTokenNums}</span></i></li>
                <li><i>Guesses:&nbsp;<span id="user-guesses">{this.state.userGuesses}</span></i></li>
              </ul>
            </div>
    
            <div className="small2">
              <h2 className="artistic-text3">Contract</h2>
              <div className="tupian">
                <img src={etherLogo} alt="Contract" />
              </div>
              <ul className="ull">
                <li><i>Contract: <span>{this.state.owner}</span></i></li>
                <li><i>Balance: <span>{this.state.contractBalance}</span></i></li>
                <li>
                  <i>Buy Tokens:&nbsp;
                    <input id="token-amount" type="number" />
                    <button className="btn btn-primary" id="token-amount-btn">Buy</button>
                  </i>
                </li>
                <li>
                  <i>Make Guess:&nbsp;
                    <input id="user-guess" type="number" min="1" max="1000000" />
                    <button className="btn btn-primary" id="user-guess-btn">Guess</button>
                  </i>
                </li>
              </ul>
            </div>
            <div className="extra1">
              <button>Click to close game</button>
            </div>
            </>
            ): (
              <>
              <div class="small1">
                <h2 class="artistic-text3">Close Game Info</h2>
                <div class="tupian">
                  <img src={winLogo} alt="" />
                </div>
                <ul class="ull">
                  <li> <i>Winner:<span id="winner-address"> </span></i> </li>
                  <li><i>Guess(SHA3):<span id="winning-guess"></span></i></li>
                  <button onclick="return closeGame()"> Get winning INFO </button>
                  <button id="transfer-funds-btn" onclick="return transferFunds()"> <a href="index.html">Transfer Funds </a></button>
                </ul>
              </div>
              </>
            )
          }
        </div>        
        <footer>
          <div className="artistic-text2">© 2024 Babymonster(academic)</div>
        </footer>
      </>
    );
  }
}
export default App;

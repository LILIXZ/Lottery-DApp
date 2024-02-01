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
    buyTokenAmount: 0,
    guessNumber: "",
    winnerAddress: "",
    winnerGuess: "",
    loading: false
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
      this.setState({loading: true});

      try{
        await lottery.methods.makeUser().send({
          gas: 140000, 
          from: this.state.player
        });
      }catch(error){
        console.error(error);
      }
      this.setState({loading: false});
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

    this.setState({loading: false});
  }

  handleBuyToken = (event) => {
    this.setState({ buyTokenAmount: event.target.value });
  }

  handleChangeGuess = (event) => {
    this.setState({ guessNumber: event.target.value });
  }

  async buyToken(){
    if (this.state.buyTokenAmount < 1) {
      alert("Please input amount of tokens.")
      return false;
    }
    try{
      this.setState({loading: true});
      await lottery.methods.addTokens().send({
        from: this.state.player,
        value: web3.utils.toWei(this.state.buyTokenAmount * 0.02, 'ether')
      });
  
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
  
      this.setState({ buyTokenAmount: 0 }) 
      this.setState({loading: false});
    } catch(error){
      console.error('Error buying token:', error);
      this.setState({loading: false});
    }
    
  }

  async makeGuess(){
    if (this.state.guessNumber < 1 || this.state.guessNumber > 10){
      alert("Please input a guess number between 1 to 10.")
      return false
    }
    
    try{
      this.setState({loading: true});
      await lottery.methods.makeGuess(this.state.guessNumber).send({
        from: this.state.player,
        gas: 140000
      });
      this.setState({ guessNumber: "" }) 
  
      // populate account
      await lottery.methods.userTokens(this.state.player).call().then((r) => {
        this.setState({playerTokenNums: Number(r)});
      });
      await web3.eth.getBalance(this.state.player).then((res)=>{
        this.setState({playerBalance: web3.utils.fromWei(res, 'ether') + ' ether'});
      })
      var guesses_string = "";
      await lottery.methods.userGuesses(this.state.player).call().then((guesses) => {
        for(var i = 0; i < guesses.length; i++) {
          guesses_string += (guesses[i] + ",");
        }
        this.setState({userGuesses: guesses_string.substr(0, guesses_string.length - 1)});
      });
    }catch(error){
      console.error(error)
    }
    
    
    this.setState({loading: false});
  }

  async closeGame(){
    try {
      this.setState({loading: true});
      await lottery.methods.reimburseTokens().send({
        from: this.state.owner,
        gas: 140000
      });
      await lottery.methods.closeGame().call({
        from: this.state.owner,
        gas: 140000,
      });
      this.setState({showCloseGameInfo: true}, async() => {
        await lottery.methods.winningGuess().call().then((res) => {
          this.setState({ winnerGuess: res });
        });
        await lottery.methods.winnerAddress().call().then((res) => {
          this.setState({ winnerAddress: res });
        });
      });
      this.setState({loading: false});
    } catch (error) {
      this.setState({loading: false});
      console.error('Error closing game:', error);
    }
  };

  async transferFunds(){
    try {
      this.setState({loading: true});
      // 调用智能合约的 getPrice 函数
      await lottery.methods.getPrice().send({
        from: this.state.owner,
        gas: 140000
      });

      // 更新状态
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

      this.setState({showCloseGameInfo: false});
      this.setState({loading: false});
    } catch (error) {
      console.error('Error transferring funds:', error);
    }
  };

  render() {
    return (
      <>
        {this.state.loading && (
          <div className="loading-overlay">
            <div className="loading-spinner"></div>
          </div>
        )}
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
                    <input id="token-amount" type="number" value={this.state.buyTokenAmount} onChange={this.handleBuyToken} />
                    <button className="btn btn-primary" id="token-amount-btn" onClick={async() => {await this.buyToken();}}>Buy</button>
                  </i>
                </li>
                <li>
                  <i>Make Guess:&nbsp;
                    <input id="user-guess" type="number" min="1" max="10" value={this.state.guessNumber} onChange={this.handleChangeGuess} />
                    <button className="btn btn-primary" id="user-guess-btn" onClick={async() => {await this.makeGuess();}}>Guess</button>
                  </i>
                </li>
              </ul>
            </div>
            <div className="extra1">
              <button onClick={async() => {await this.closeGame();}}>Click to close game</button>
            </div>
            </>
            ): (
              <>
              <div className="small1">
                <h2 className="artistic-text3">Close Game Info</h2>
                <div className="tupian">
                  <img src={winLogo} alt="" />
                </div>
                <ul className="ull">
                  <li><i>Winner:&nbsp;<span id="winner-address">{this.state.winnerAddress}</span></i> </li>
                  <li><i>Guess(SHA3):&nbsp;<span id="winning-guess">{this.state.winnerGuess}</span></i></li>
                  {/* <button> Get winning INFO </button> */}
                  <button id="transfer-funds-btn" onClick={async() => {await this.transferFunds();}}>Transfer Funds</button>
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

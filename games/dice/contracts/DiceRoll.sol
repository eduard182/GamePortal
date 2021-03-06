pragma solidity ^0.4.8;

contract owned {
    address public owner;

    function owned() {
        owner = msg.sender;
    }

    modifier onlyOwner {
        if (msg.sender != owner) throw;
        _;
    }

    function transferOwnership(address newOwner) onlyOwner {
        owner = newOwner;
    }
}

contract ERC20 {
    function balanceOf(address _addr) returns(uint);

    function transfer(address _to, uint256 _value);

    function transferFrom(address _from, address _to, uint256 _value) returns(bool success);
}

contract DiceRoll is owned {

    address public addr_erc20 = 0x95a48dca999c89e4e284930d9b9af973a7481287;
    ERC20 erc = ERC20(addr_erc20);
    bool public ownerStoped = false;
    uint public minBet = 100000;
    uint public maxBet = 1000000000;
    uint public countRolls = 0;
    uint public totalEthSended = 0;
    uint public totalEthPaid = 0;

    mapping(address => uint) public totalRollsByUser;
    /**
     * @dev List of used random numbers 
     */
    enum GameState {
        InProgress,
        PlayerWon,
        PlayerLose,
        NoBank
    }
	
    event logId(bytes32 Id);

    struct Game {
        address player;
        uint bet;
        uint chance;
        bytes32 seed;
        GameState state;
        uint rnd;
		uint block;
    }
    
    mapping(bytes32 => bool) public usedRandom;
    mapping(bytes32 => Game) public listGames;
	
    modifier stoped() {
        if (ownerStoped == true) {
            throw;
        }
        _;
    }
    
    function () payable {

    }

    function Stop() public onlyOwner {
        if (ownerStoped == false) {
            ownerStoped = true;
        } else {
            ownerStoped = false;
        }
    }

    function setAddress(address adr) public onlyOwner{
        addr_erc20 = adr;
        ERC20 erc = ERC20(adr);
    }

    function getBank() public constant returns(uint) {
        return erc.balanceOf(this);
    }
    // starts a new game
    function roll(uint PlayerBet, uint PlayerNumber, bytes32 seeds) public
        stoped
    {
        if (!erc.transferFrom(msg.sender, this, PlayerBet)) {
            throw;
        }
        if (PlayerBet < minBet || PlayerBet > maxBet) {
            throw; // incorrect bet
        }
        
        if (usedRandom[seeds]) {
            throw;
        }
       
        usedRandom[seeds] = true;
        if(PlayerNumber > 65536 - 1310 || PlayerNumber == 0){
            throw;
        } 
		uint b = block.number;
        uint bet = PlayerBet;
        uint chance = PlayerNumber;
        uint payout = bet * (65536 - 1310) / chance;
        bool isBank = true;
        
        logId(seeds);
        
        listGames[seeds] = Game({
            player: msg.sender,
            bet: bet,
            chance: chance,
            seed: seeds,
            state: GameState.InProgress,
            rnd: 0,
			block: b
        });
        
        if (payout > getBank()) {
            isBank = false;
            listGames[seeds].state = GameState.NoBank;
            throw;
        }
        
        totalRollsByUser[msg.sender]++;
    }

    function confirm(bytes32 random_id, uint8 _v, bytes32 _r, bytes32 _s) public
    {
        if(listGames[random_id].state == GameState.PlayerWon ||
        listGames[random_id].state == GameState.PlayerLose){
            throw;
        }
        
        if (ecrecover(random_id, _v, _r, _s) != owner) {// owner
            Game game = listGames[random_id];
            uint payout = game.bet * (65536 - 1310) / game.chance;
            uint rnd = uint256(sha3(_s))%65536;
            game.rnd = rnd;
			
            if (game.state != GameState.NoBank) {
                countRolls++;
               // uint profit = payout - game.bet;
                totalEthPaid += game.bet;
                //Limitation of payment 1/10BR
                if ((payout - game.bet) > getBank() / 10) {
                    throw;
                }
                
                if (rnd > game.chance) {
                    listGames[random_id].state = GameState.PlayerLose;
                } 
                else {
                    listGames[random_id].state = GameState.PlayerWon;
                    erc.transfer(game.player, payout);
                    totalEthSended += payout;
                }
            }
        }
    }
    
	/*function timeout(bytes32 random_id) public
		stoped
	{
		Game game = listGames[random_id];
		uint b = block.number;
		uint diff = b - game.block;
		
		if(game.state == GameState.InProgress && diff > 3){
			erc.transfer(game.player, game.bet);
		}
	}*/

    function getCount() public constant returns(uint) {
        return totalRollsByUser[msg.sender];
    }
    
    function getShowRnd(bytes32 random_id) public constant returns(uint) {
        Game memory game = listGames[random_id];

        if (game.player == 0) {
            // game doesn't exist
            throw;
        }

        return game.rnd;
    }

    function getStateByAddress(bytes32 random_id) public constant returns(GameState) {
        Game memory game = listGames[random_id];

        if (game.player == 0) {
            // game doesn't exist
            throw;
        }

        return game.state;
    }

    function withdraw(uint amount) public onlyOwner {
        if (msg.sender.send(amount)) {}
    }
}
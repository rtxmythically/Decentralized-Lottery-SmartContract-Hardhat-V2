// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract ScratchLotteryV2 is Ownable, ReentrancyGuard {
    /* ---------------- 事件 ---------------- */
    event Play(address indexed player, uint8 prizeTier, uint256 amount, bytes32 txHashUsed);
    event Refill(address indexed from, uint256 amount);
    event Withdraw(address indexed to, uint256 amount);

    /* ---------------- 結構體 ---------------- */
    struct Prize {
        uint256 amount;   // LAT 數量（wei）
        uint16  left;     // 當前剩餘
        uint16  total;    // 初始總量（快照）
        uint16  probability; // 權重（萬分之一）
    }

    /* ---------------- 狀態變量 ---------------- */
    mapping(uint8 => Prize)     public prizes;           // 0-6 獎項
    mapping(address => uint8)   public playedToday;       // 今天玩了幾次
    mapping(address => uint256) public lastPlayedDay;     // 上次玩的「日戳」
    
    uint8 public constant MAX_PLAY = 30;
    uint256 public constant FEE = 0.01 ether;
    uint256 public constant DENOM = 10_000;

    /* ---------------- 建構子 ---------------- */
    constructor() Ownable(msg.sender) {
        // 概率配置：綜合中獎率 ≈ 50%（不含謝謝參與）
        prizes[0] = Prize(0.01 ether, 1000, 1000, 2500);
        prizes[1] = Prize(0.02 ether, 500, 500, 1200);
        prizes[2] = Prize(0.05 ether, 100, 100, 600);
        prizes[3] = Prize(0.1 ether, 20, 20, 120);
        prizes[4] = Prize(0.2 ether, 10, 10, 60);
        prizes[5] = Prize(1 ether, 1, 1, 6);
        prizes[6] = Prize(0, type(uint16).max, type(uint16).max, 4512); // 謝謝參與
    }

    /* ---------------- 核心玩法 ---------------- */
    function play() external payable nonReentrant {
        require(msg.value == FEE, "Bad fee");

        uint256 today = _currentDay();
        if (lastPlayedDay[msg.sender] < today) {
            // 新的一天，重置次數
            playedToday[msg.sender] = 0;
            lastPlayedDay[msg.sender] = today;
        }
        require(playedToday[msg.sender] < MAX_PLAY, "No chance left");

        bytes32 randSeed = bytes32(uint256(uint32(uint256(keccak256(abi.encodePacked(
            msg.sender, block.timestamp, tx.origin))) >> (256 - 16))));
        uint16 dice = uint16(uint256(randSeed) % DENOM);

        uint8 tier = 6; // 預設為謝謝參與
        uint16 cum = 0;
        for (uint8 i = 0; i < 6; i++) {
            cum += prizes[i].probability;
            if (dice < cum && prizes[i].left > 0) {
                tier = i;
                break;
            }
        }

        if (tier < 6) {
            prizes[tier].left--;
            uint256 reward = prizes[tier].amount;
            (bool ok, ) = msg.sender.call{value: reward}("");
            require(ok, "Send fail");
        }

        playedToday[msg.sender]++;
        emit Play(msg.sender, tier, tier == 6 ? 0 : prizes[tier].amount, randSeed);
    }

    function _currentDay() internal view returns (uint256) {
        return block.timestamp / 1 days;
    }

    /* ---------------- 管理功能 ---------------- */
    function refill() external payable onlyOwner {
        emit Refill(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external onlyOwner {
        (bool ok, ) = owner().call{value: amount}("");
        require(ok, "Withdraw fail");
        emit Withdraw(owner(), amount);
    }

    function setPrize(uint8 tier, uint256 amount, uint16 left, uint16 prob) external onlyOwner {
        require(tier <= 6, "Bad tier");
        prizes[tier].amount = amount;
        prizes[tier].left = left;
        prizes[tier].total = left;
        prizes[tier].probability = prob;
    }

    receive() external payable {}
}

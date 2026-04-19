// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GameItems is ERC1155, Ownable {
    uint256 public constant GOLD = 1;
    uint256 public constant WOOD = 2;
    uint256 public constant IRON = 3;

    uint256 public constant LEGENDARY_SWORD = 1001;
    uint256 public constant DRAGON_SHIELD = 1002;

    constructor()
        ERC1155("https://game.example/api/item/{id}.json")
        Ownable(msg.sender)
    {}

    function mint(address to, uint256 id, uint256 amount) external onlyOwner {
        _mint(to, id, amount, "");
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts)
        external
        onlyOwner
    {
        _mintBatch(to, ids, amounts, "");
    }

    function craftSword() external {
        require(balanceOf(msg.sender, GOLD) >= 100, "Not enough gold");
        require(balanceOf(msg.sender, IRON) >= 50, "Not enough iron");

        _burn(msg.sender, GOLD, 100);
        _burn(msg.sender, IRON, 50);

        _mint(msg.sender, LEGENDARY_SWORD, 1, "");
    }

    function craftShield() external {
        require(balanceOf(msg.sender, WOOD) >= 100, "Not enough wood");
        require(balanceOf(msg.sender, IRON) >= 40, "Not enough iron");

        _burn(msg.sender, WOOD, 100);
        _burn(msg.sender, IRON, 40);

        _mint(msg.sender, DRAGON_SHIELD, 1, "");
    }

    function uri(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(id)));
    }
}
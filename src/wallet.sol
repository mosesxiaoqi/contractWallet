// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MultiSigWallet {
    address[] public owners;        // 多签持有人的地址
    uint256 public required;        // 执行交易所需的签名数
    mapping(address => bool) public isOwner; // 判断某地址是否为持有者
    uint256 public proposalCount;   // 提案计数
    mapping(uint256 => Proposal) public proposals; // 提案
    mapping(uint256 => mapping(address => bool)) public votes; // 投票记录

    struct Proposal {
        uint256 id;
        address payable to;
        uint256 value;
        bytes data;
        uint256 voteCount;
        bool executed;
        address proposer;
    }

    event ProposalCreated(uint256 id, address proposer, address to, uint256 value, bytes data);
    event Voted(uint256 id, address voter);
    event Executed(uint256 id);

    // 构造函数
    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid required signatures");
        
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid address");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    // 提交提案
    function submitProposal(address payable _to, uint256 _value, bytes memory _data) public {
        require(isOwner[msg.sender], "Only owners can submit proposals");

        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.proposer = msg.sender;
        newProposal.to = _to;
        newProposal.value = _value;
        newProposal.data = _data;
        newProposal.voteCount = 0;
        newProposal.executed = false;

        emit ProposalCreated(proposalCount, msg.sender, _to, _value, _data);
    }

    // 投票确认提案
    function vote(uint256 _proposalId) public {
        require(isOwner[msg.sender], "Only owners can vote");
        Proposal storage proposal = proposals[_proposalId];

        require(!proposal.executed, "Proposal already executed");
        require(!votes[_proposalId][msg.sender], "You already voted");

        votes[_proposalId][msg.sender] = true;
        proposal.voteCount++;

        emit Voted(_proposalId, msg.sender);

        // 如果投票数达到要求，执行提案
        if (proposal.voteCount >= required) {
            _executeProposal(_proposalId);
        }
    }

    // 执行提案
    function _executeProposal(uint256 _proposalId) internal {
        Proposal storage proposal = proposals[_proposalId];

        require(proposal.voteCount >= required, "Not enough votes");
        require(!proposal.executed, "Proposal already executed");

        (bool success, ) = proposal.to.call{value: proposal.value}(proposal.data);
        require(success, "Transaction execution failed");

        proposal.executed = true;

        emit Executed(_proposalId);
    }

    // 获取多签持有人的地址
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    // 获取提案的详细信息
    function getProposal(uint256 _proposalId) public view returns (Proposal memory) {
        return proposals[_proposalId];
    }

    // 获取提案的投票数
    function getProposalVotes(uint256 _proposalId) public view returns (uint256) {
        return proposals[_proposalId].voteCount;
    }
}
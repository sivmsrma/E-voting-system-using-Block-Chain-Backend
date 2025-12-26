// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Voting {
    struct Candidate {
        uint id;
        string name;
        uint voteCount;
    }

    struct Election {
        uint id;
        string name;
        uint startTime;
        uint endTime;
        bool started;
        bool ended;
        uint totalVotes;
    }

    address public owner;
    uint public electionCount;
    uint public currentElectionId;

    // Mapping: electionId => candidates array
    mapping(uint => Candidate[]) public electionCandidates;
    
    // Mapping: electionId => Election details
    mapping(uint => Election) public elections;
    
    // Mapping: electionId => voter address => hasVoted
    mapping(uint => mapping(address => bool)) public hasVoted;

    event ElectionCreated(uint indexed electionId, string name);
    event CandidateAdded(uint indexed electionId, string name);
    event ElectionStarted(uint indexed electionId, uint duration);
    event ElectionEnded(uint indexed electionId);
    event Voted(uint indexed electionId, address indexed voter, uint candidateId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    modifier electionExists(uint _electionId) {
        require(_electionId < electionCount, "Election does not exist");
        _;
    }

    modifier activeElection(uint _electionId) {
        require(elections[_electionId].started, "Election not started");
        require(!elections[_electionId].ended, "Election has ended");
        require(block.timestamp < elections[_electionId].endTime, "Election time expired");
        _;
    }

    constructor() {
        owner = msg.sender;
        electionCount = 0;
    }

    function createElection(string memory _name) public onlyOwner {
        require(bytes(_name).length > 0, "Election name cannot be empty");
        
        // End previous election if it exists and is running
        if (electionCount > 0) {
            uint prevId = electionCount - 1;
            if (elections[prevId].started && !elections[prevId].ended) {
                if (block.timestamp >= elections[prevId].endTime) {
                    elections[prevId].ended = true;
                    emit ElectionEnded(prevId);
                } else {
                    revert("Previous election is still active");
                }
            }
        }

        uint newElectionId = electionCount;
        elections[newElectionId] = Election({
            id: newElectionId,
            name: _name,
            startTime: 0,
            endTime: 0,
            started: false,
            ended: false,
            totalVotes: 0
        });

        currentElectionId = newElectionId;
        electionCount++;

        emit ElectionCreated(newElectionId, _name);
    }

    function addCandidate(string memory _name) public onlyOwner {
        require(electionCount > 0, "Create an election first");
        uint electionId = currentElectionId;
        require(!elections[electionId].started, "Cannot add candidates to started election");
        
        Candidate[] storage candidates = electionCandidates[electionId];
        candidates.push(Candidate({
            id: candidates.length,
            name: _name,
            voteCount: 0
        }));

        emit CandidateAdded(electionId, _name);
    }

    function startElection(uint _durationInMinutes) public onlyOwner {
        require(electionCount > 0, "Create an election first");
        uint electionId = currentElectionId;
        require(!elections[electionId].started, "Election already started");
        require(electionCandidates[electionId].length >= 2, "Need at least 2 candidates");

        elections[electionId].startTime = block.timestamp;
        elections[electionId].endTime = block.timestamp + (_durationInMinutes * 1 minutes);
        elections[electionId].started = true;

        emit ElectionStarted(electionId, _durationInMinutes);
    }

    function vote(uint _candidateId) public {
        require(electionCount > 0, "No elections available");
        uint electionId = currentElectionId;
        
        require(elections[electionId].started, "Election not started");
        require(!elections[electionId].ended, "Election has ended");
        require(block.timestamp < elections[electionId].endTime, "Election time expired");
        require(!hasVoted[electionId][msg.sender], "You have already voted");
        require(_candidateId < electionCandidates[electionId].length, "Invalid candidate ID");

        // Check if election should be ended
        if (block.timestamp >= elections[electionId].endTime) {
            elections[electionId].ended = true;
            emit ElectionEnded(electionId);
            revert("Election has ended");
        }

        hasVoted[electionId][msg.sender] = true;
        electionCandidates[electionId][_candidateId].voteCount++;
        elections[electionId].totalVotes++;

        emit Voted(electionId, msg.sender, _candidateId);
    }

    function endElection() public onlyOwner {
        require(electionCount > 0, "No elections available");
        uint electionId = currentElectionId;
        require(elections[electionId].started, "Election not started");
        require(!elections[electionId].ended, "Election already ended");

        elections[electionId].ended = true;
        emit ElectionEnded(electionId);
    }

    function getCurrentElection() public view returns (
        uint id,
        string memory name,
        uint startTime,
        uint endTime,
        bool started,
        bool ended,
        uint totalVotes,
        uint candidateCount
    ) {
        require(electionCount > 0, "No elections created");
        Election memory election = elections[currentElectionId];
        return (
            election.id,
            election.name,
            election.startTime,
            election.endTime,
            election.started,
            election.ended,
            election.totalVotes,
            electionCandidates[currentElectionId].length
        );
    }

    function getAllCandidates() public view returns (Candidate[] memory) {
        require(electionCount > 0, "No elections created");
        return electionCandidates[currentElectionId];
    }

    function getElectionCandidates(uint _electionId) public view electionExists(_electionId) returns (Candidate[] memory) {
        return electionCandidates[_electionId];
    }

    function getElection(uint _electionId) public view electionExists(_electionId) returns (
        uint id,
        string memory name,
        uint startTime,
        uint endTime,
        bool started,
        bool ended,
        uint totalVotes
    ) {
        Election memory election = elections[_electionId];
        return (
            election.id,
            election.name,
            election.startTime,
            election.endTime,
            election.started,
            election.ended,
            election.totalVotes
        );
    }

    function getAllElections() public view returns (Election[] memory) {
        Election[] memory allElections = new Election[](electionCount);
        for (uint i = 0; i < electionCount; i++) {
            allElections[i] = elections[i];
        }
        return allElections;
    }

    function getRemainingTime() public view returns (uint) {
        if (electionCount == 0) return 0;
        Election memory election = elections[currentElectionId];
        if (!election.started || election.ended) return 0;
        if (block.timestamp >= election.endTime) return 0;
        return election.endTime - block.timestamp;
    }

    function hasUserVoted(uint _electionId, address _voter) public view electionExists(_electionId) returns (bool) {
        return hasVoted[_electionId][_voter];
    }
}

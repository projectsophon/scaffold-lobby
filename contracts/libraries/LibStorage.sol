// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

// Type imports
import {
    Planet,
    PlanetExtendedInfo,
    PlanetExtendedInfo2,
    PlanetEventMetadata,
    RevealedCoords,
    Player,
    ArrivalData,
    Artifact
} from "../DFTypes.sol";
import {
    ClaimedCoords
} from "../RaceTypes.sol";

struct RaceStorage {
    uint256 roundEnd;
    uint256 CLAIM_PLANET_COOLDOWN;

    /**
     * Map from player address to the list of planets they have claimed.
     */
    mapping(address => uint256[]) claimedPlanetsOwners;

    /**
     * List of all claimed planetIds
     */
    uint256[] claimedIds;

    /**
     * Map from planet id to claim data.
     */
    mapping(uint256 => ClaimedCoords) claimedCoords;

    mapping(address => uint256) lastClaimTimestamp;
}

// TODO: How can DF provide this?
struct GameStorage {
    // Contract housekeeping
    address diamondAddress;
    // admin controls
    bool paused;
    uint256 TOKEN_MINT_END_TIMESTAMP;
    uint256 planetLevelsCount;
    uint256[] planetLevelThresholds;
    uint256[] cumulativeRarities;
    uint256[] initializedPlanetCountByLevel;
    // Game world state
    uint256[] planetIds;
    uint256[] revealedPlanetIds;
    address[] playerIds;
    uint256 worldRadius;
    uint256 planetEventsCount;
    uint256 miscNonce;
    mapping(uint256 => Planet) planets;
    mapping(uint256 => RevealedCoords) revealedCoords;
    mapping(uint256 => PlanetExtendedInfo) planetsExtendedInfo;
    mapping(uint256 => PlanetExtendedInfo2) planetsExtendedInfo2;
    mapping(uint256 => uint256) artifactIdToPlanetId;
    mapping(uint256 => uint256) artifactIdToVoyageId;
    mapping(address => Player) players;
    // maps location id to planet events array
    mapping(uint256 => PlanetEventMetadata[]) planetEvents;
    // maps event id to arrival data
    mapping(uint256 => ArrivalData) planetArrivals;
    mapping(uint256 => uint256[]) planetArtifacts;
    // Artifact stuff
    mapping(uint256 => Artifact) artifacts;
    // Capture Zones
    uint256 nextChangeBlock;
}

library LibStorage {
    // Storage are structs where the data gets updated throughout the lifespan of the game
    bytes32 constant RACE_TO_CENTER_STORAGE = keccak256("lobby.storage.racetocenter");

    function raceStorage() internal pure returns (RaceStorage storage rs) {
        bytes32 position = RACE_TO_CENTER_STORAGE;
        assembly {
            rs.slot := position
        }
    }

    //DarkForest storage that we need
    bytes32 constant GAME_STORAGE_POSITION = keccak256("darkforest.storage.game");

    function gameStorage() internal pure returns (GameStorage storage gs) {
        bytes32 position = GAME_STORAGE_POSITION;
        assembly {
            gs.slot := position
        }
    }
}

contract WithRaceStorage {
    function rs() internal pure returns (RaceStorage storage) {
        return LibStorage.raceStorage();
    }

    function gs() internal pure returns (GameStorage storage) {
        return LibStorage.gameStorage();
    }
}

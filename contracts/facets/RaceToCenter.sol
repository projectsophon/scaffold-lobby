// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {ABDKMath64x64} from "../vendor/libraries/ABDKMath64x64.sol";
import {WithRaceStorage} from "../libraries/LibStorage.sol";

import {
    Planet
} from "../DFTypes.sol";
import {
    ClaimedCoords,
    LastClaimedStruct
} from "../RaceTypes.sol";

interface DarkForest {
    function refreshPlanet(uint256 location) external;

    function checkRevealProof(
        uint256[2] memory _a,
        uint256[2][2] memory _b,
        uint256[2] memory _c,
        uint256[9] memory _input
    ) external view returns (bool);
}

/**
 * Externally from the core game, in round 3 of dark forest v0.6, we allow players to 'claim'
 * planets. The person who claims the planet closest to (0, 0) is the winner and the rest are
 * ordered by their closest claimed planet.
 */
contract RaceToCenter is WithRaceStorage {

    event LocationClaimed(address revealer, address previousClaimer, uint256 loc);

    function getScore(address player) public view returns (uint256) {
        uint256 bestScore = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        uint256[] storage planetIds = rs().claimedPlanetsOwners[player];

        for (uint256 i = 0; i < planetIds.length; i++) {
            ClaimedCoords memory claimed = rs().claimedCoords[planetIds[i]];
            if (bestScore > claimed.score) {
                bestScore = claimed.score;
            }
        }

        return bestScore;
    }

    function getClaimedCoords(uint256 locationId) public view returns (ClaimedCoords memory) {
        return rs().claimedCoords[locationId];
    }

    /**
     * Assuming that the given player is allowed to claim the given planet, and that the distance is
      correct, update the data that the scoring function will need.
     */
    function storePlayerClaim(
        address player,
        uint256 planetId,
        uint256 distance,
        uint256 x,
        uint256 y
    ) internal returns (address) {
        ClaimedCoords memory oldClaim = getClaimedCoords(planetId);
        uint256[] storage playerClaims = rs().claimedPlanetsOwners[player];
        uint256[] storage oldPlayerClaimed = rs().claimedPlanetsOwners[oldClaim.claimer];

        // if uninitialized set claimedCoords to
        if (rs().claimedCoords[planetId].claimer == address(0)) {
            rs().claimedIds.push(planetId);
            playerClaims.push(planetId);
            rs().claimedCoords[planetId] = ClaimedCoords({
                locationId: planetId,
                x: x,
                y: y,
                claimer: player,
                score: distance,
                claimedAt: block.timestamp
            });
            // Only execute if player is not current claimer
        } else if (rs().claimedCoords[planetId].claimer != player) {
            playerClaims.push(planetId);
            rs().claimedCoords[planetId].claimer = player;
            rs().claimedCoords[planetId].claimedAt = block.timestamp;
            for (uint256 i = 0; i < oldPlayerClaimed.length; i++) {
                if (oldPlayerClaimed[i] == planetId) {
                    oldPlayerClaimed[i] = oldPlayerClaimed[oldPlayerClaimed.length - 1];
                    oldPlayerClaimed.pop();
                    break;
                }
            }
        }
        // return previous claimer for event emission
        return oldClaim.claimer;
    }

    function getNClaimedPlanets() public view returns (uint256) {
        return rs().claimedIds.length;
    }

    function bulkGetClaimedPlanetIds(uint256 startIdx, uint256 endIdx)
        public
        view
        returns (uint256[] memory ret)
    {
        // return slice of revealedPlanetIds array from startIdx through endIdx - 1
        ret = new uint256[](endIdx - startIdx);
        for (uint256 i = startIdx; i < endIdx; i++) {
            ret[i - startIdx] = rs().claimedIds[i];
        }
    }

    function bulkGetClaimedCoordsByIds(uint256[] calldata ids)
        public
        view
        returns (ClaimedCoords[] memory ret)
    {
        ret = new ClaimedCoords[](ids.length);

        for (uint256 i = 0; i < ids.length; i++) {
            ret[i] = rs().claimedCoords[ids[i]];
        }
    }


    function claimPlanetCooldown() public view returns (uint256) {
        return rs().CLAIM_PLANET_COOLDOWN;
    }

    function bulkGetLastClaimTimestamp(uint256 startIdx, uint256 endIdx)
        public
        view
        returns (LastClaimedStruct[] memory ret)
    {
        ret = new LastClaimedStruct[](endIdx - startIdx);
        for (uint256 i = startIdx; i < endIdx; i++) {
            address player = gs().playerIds[i];
            ret[i - startIdx] = LastClaimedStruct({
                player: player,
                lastClaimTimestamp: rs().lastClaimTimestamp[player]
            });
        }
    }

    function getLastClaimTimestamp(address player) public view returns (uint256) {
        return rs().lastClaimTimestamp[player];
    }

    /**
     * Calculates the distance of the given coordinate from (0, 0).
     */
    function distanceFromCenter(uint256 x, uint256 y) private pure returns (uint256) {
        if (x == 0 && y == 0) {
            return 0;
        }

        uint256 distance =
            ABDKMath64x64.toUInt(
                ABDKMath64x64.sqrt(
                    ABDKMath64x64.add(
                        ABDKMath64x64.pow(ABDKMath64x64.fromUInt(x), 2),
                        ABDKMath64x64.pow(ABDKMath64x64.fromUInt(y), 2)
                    )
                )
            );

        return distance;
    }

    // `x`, `y` are in `{0, 1, 2, ..., LOCATION_ID_UB - 1}`
    // by convention, if a number `n` is greater than `LOCATION_ID_UB / 2`, it is considered a negative number whose "actual" value is `n - LOCATION_ID_UB`
    // this code snippet calculates the absolute value of `x` or `y` (given the above convention)
    function getAbsoluteModP(uint256 n) private pure returns (uint256) {
        uint256 LOCATION_ID_UB =
            21888242871839275222246405745257275088548364400416034343698204186575808495617;
        require(n < LOCATION_ID_UB, "Number outside of AbsoluteModP Range");
        if (n > LOCATION_ID_UB / 2) {
            return LOCATION_ID_UB - n;
        }

        return n;
    }

    // TODO: Add onlyAdmin stuff
    // function setRoundEnd(uint256 _roundEnd) public onlyOwner {
    //     roundEnd = _roundEnd;
    // }

    /**
     * In dark forest v0.6 r3, players can claim planets that own.
     * This will reveal a planets a coordinates to all other players.
     * A Player's score is determined by taking the distance of their closest planet from the center of the universe.
     * A planet can be claimed multiple times, but only the last player to claim a planet can use it as part of their score.
     */
    function claim(
        uint256[2] memory _a,
        uint256[2][2] memory _b,
        uint256[2] memory _c,
        uint256[9] memory _input
    ) public {
        require(block.timestamp < rs().roundEnd, "Cannot claim planets after the round has ended");
        require(
            block.timestamp - rs().lastClaimTimestamp[msg.sender] > rs().CLAIM_PLANET_COOLDOWN,
            "wait for cooldown before revealing again"
        );
        require(
            gs().planetsExtendedInfo[_input[0]].isInitialized,
            "Cannot claim uninitialized planet"
        );
        require(DarkForest(address(this)).checkRevealProof(_a, _b, _c, _input), "Failed reveal pf check");
        uint256 x = _input[2];
        uint256 y = _input[3];

        DarkForest(address(this)).refreshPlanet(_input[0]);
        Planet memory planet = gs().planets[_input[0]];
        require(planet.owner == msg.sender, "Only planet owner can perform operation on planets");
        require(planet.planetLevel >= 3, "Planet level must >= 3");
        require(
            !gs().planetsExtendedInfo[_input[0]].destroyed,
            "Cannot claim destroyed planet"
        );
        rs().lastClaimTimestamp[msg.sender] = block.timestamp;
        address previousClaimer =
            storePlayerClaim(
                msg.sender,
                _input[0],
                distanceFromCenter(getAbsoluteModP(x), getAbsoluteModP(y)),
                x,
                y
            );
        emit LocationClaimed(msg.sender, previousClaimer, _input[0]);
    }
}

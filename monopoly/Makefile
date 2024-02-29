include .env
export $(shell sed 's/=.*//' .env)

.PHONY: install build test

build:
	forge build
testAll:
	forge test -${v} --gas-report
coverage:
	forge coverage --report lcov
view-coverage:
	genhtml -o coverage-report lcov.info
	open coverage-report/index.html

test:
	forge test -vvv --match-path=test/Monopoly.t.sol

testInit:
	forge test -vvv --match-path=test/MonopolyInit.t.sol

testProps:
	forge test -vvv --match-path=test/MonopolyProps.t.sol

testAdminPermission:
	forge test -vv --match-path=test/MonopolyPermission.t.sol

testLandVault:
	forge test -vv --match-path=test/LandVault.t.sol

testSushiModel:
	forge test -vv --match-path=test/SushiModel.t.sol

gas-price:
	cast gas-price --rpc-url=${BASE}

deploy:
	if [ "$(network)" = "testnet" ]; then \
		forge script --rpc-url=${TESTNET} --gas-price=$(shell cast gas-price --rpc-url=${TESTNET}) \
		--private-key=${PK} script/Monopoly.s.sol --broadcast --verify -vvvv; \
	elif [ "$(network)" = "base" ]; then \
		forge script --rpc-url=${BASE} --gas-price=$(shell cast gas-price --rpc-url=${BASE}) \
		--private-key=${PK} script/Monopoly.s.sol --broadcast --verify -vvvv; \
	else \
		forge script --rpc-url=${LOCAL} --gas-price=$(shell cast gas-price --rpc-url=${TESTNET}) \
		--private-key=${LOCAL_PK} script/Monopoly.s.sol --broadcast --verify -vvvv; \
	fi

verify-fmp:
	forge verify-contract --chain-id 5 --watch ${FMP_IMPL} \
	src/FMP.sol:FomopolyToken --etherscan-api-key ${ETHERSCAN_API_KEY}

verify-monopoly:
	forge verify-contract --chain-id 5 --watch ${MONOPOLY_IMPL} \
	src/Monopoly.sol:Monopoly --etherscan-api-key ${ETHERSCAN_API_KEY}

buyLand:
	cast send --rpc-url=${TESTNET} --private-key=${PK} --value=5000000000000000  ${MONOPOLY} "buyLand()"

move:
	cast send --rpc-url=${TESTNET} --private-key=${PK} ${MONOPOLY} "move(uint8)" 0

mintFMP:
	cast send --rpc-url=${TESTNET} --private-key=${PK} ${FMP} "mint(address,uint256)" 0x00B9829EFEcfc18aD792298C75C5AcAB37B99E48 10000000000000000000000

setDreceaseInterval:
	cast send --rpc-url=${TESTNET} --private-key=${PK} ${MONOPOLY} "setDecreaseInterval(uint256)" 60

setMaxLands:
	cast send --rpc-url=${TESTNET} --private-key=${PK} ${MONOPOLY} "setMaxLands(uint16)" 100

internalMintFMP:
	cast send --rpc-url=${TESTNET} --private-key=${PK} ${FMP} "internalTestMint()"

upgradeMonopoly:
	# echo "update script first"
	# forge script --rpc-url=${TESTNET} --private-key=${PK} script/UpgradeMonopoly.s.sol --broadcast --verify -vvvv

upgradeFMP:
	echo "update script first"
	# forge script --rpc-url=${TESTNET} --private-key=${PK} script/UpgradeFMP.s.sol --broadcast --verify -vvvv

owner:
	cast call --rpc-url=${TESTNET} ${FMP} "owner()"

getPlayer:
	cast call --rpc-url=${TESTNET} ${MONOPOLY} "getPlayer(address)(uint16, uint16, uint256)" 0x00B9829EFEcfc18aD792298C75C5AcAB37B99E48
	# pos, landAmount, rewardDebt

getPlayerOwnedLandIDs:
	cast call --rpc-url=${TESTNET} ${MONOPOLY} "getPlayerOwnedLandIDs(address)(uint16[],uint16)" 0x00b9829efecfc18ad792298c75c5acab37b99e48

getSystemPool:
	cast call --rpc-url=${TESTNET} ${MONOPOLY} "getSystemPool()(uint256,uint256,uint256)"

getLandPrice:
	cast call --rpc-url=${TESTNET} ${MONOPOLY} "getLandPrice(uint16)(uint256)" 2

getPendingReward:
	cast call --rpc-url=${TESTNET} ${MONOPOLY} "getPendingReward(address)(uint256,uint256)" 0x00B9829EFEcfc18aD792298C75C5AcAB37B99E48
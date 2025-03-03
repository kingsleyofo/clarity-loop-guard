Clarinet.test({
    name: "Test enhanced status tracking and health scoring",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Register node
        let block = chain.mineBlock([
            Tx.contractCall('loop-guard', 'register-node', [
                types.principal(wallet1.address)
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk();
        
        // Test adaptive rate limiting
        let updateBlocks = [];
        for(let i = 0; i < 5; i++) {
            updateBlocks.push(
                chain.mineBlock([
                    Tx.contractCall('loop-guard', 'update-node-status', [
                        types.principal(wallet1.address),
                        types.ascii("error")
                    ], wallet1.address)
                ])
            );
            chain.mineEmptyBlocks(11); // Mine enough blocks to pass rate limit
        }
        
        // Verify health score decrease
        const nodeInfo = chain.callReadOnlyFn(
            'loop-guard',
            'get-node-info',
            [types.principal(wallet1.address)],
            wallet1.address
        );
        
        // Assert health score decreased
        assert(nodeInfo.result.expectSome().expectTuple()['health-score'] < 100);
    }
});

[Previous tests remain unchanged]

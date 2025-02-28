[Previous test content]

Clarinet.test({
    name: "Test rate limiting and health checks",
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
        
        // Attempt rapid updates
        let updateBlock = chain.mineBlock([
            Tx.contractCall('loop-guard', 'update-node-status', [
                types.principal(wallet1.address),
                types.ascii("running")
            ], wallet1.address),
            Tx.contractCall('loop-guard', 'update-node-status', [
                types.principal(wallet1.address),
                types.ascii("error")
            ], wallet1.address)
        ]);
        
        updateBlock.receipts[0].result.expectOk();
        updateBlock.receipts[1].result.expectErr(types.uint(106)); // err-rate-limit
    }
});

[Remaining tests unchanged]

public final class Wallet {
    
    private let network: Network
    private let privateKey: PrivateKey
    
    public init(seed: Data, network: Network) throws {
        self.network = network
        
        // m/44'/coin_type'/0'/external
        let externalPrivateKey = try HDPrivateKey(seed: seed, network: network)
            .derived(at: 44, hardens: true)
            .derived(at: network.coinType, hardens: true)
            .derived(at: 0, hardens: true)
            .derived(at: 0) // 0 for external
        
        privateKey = try externalPrivateKey
            .derived(at: 0)
            .privateKey()
    }
    
    public init(network: Network, privateKey: String) {
        self.network = network
        self.privateKey = PrivateKey(raw: Data(hex: privateKey))
    }
    
    // MARK: - Public Methods
    
    public func generateAddress() -> String {
        return privateKey.publicKey.generateAddress()
    }
    
    public func dumpPrivateKey() -> String {
        return privateKey.raw.toHexString()
    }
    
    public func sign(rawTransaction: RawTransaction) throws -> String {
        let signTransaction = SignTransaction(
            rawTransaction: rawTransaction,
            gasPrice: Converter.toWei(GWei: Gas.price.value),
            gasLimit: Gas.limit.value
        )
        let signer = EIP155Signer(chainID: network.chainID)
        let rawData = try signer.sign(signTransaction, privateKey: privateKey)
        return rawData.toHexString().addHexPrefix()
    }
    
    /// Sign calculates an Ethereum ECDSA signature for: keccack256("\x19Ethereum Signed Message:\n" + len(message) + message))
    /// See also: https://github.com/ethereum/go-ethereum/wiki/Management-APIs#personal_sign
    ///
    /// - Parameter hex: message in hex format to sign
    /// - Returns: signiture in hex format
    /// - Throws: EthereumKitError.failedToEncode when failed to encode
    public func sign(hex: String) throws -> String {
        let prefix = "\u{19}Ethereum Signed Message:\n"
        
        let messageData = Data(hex: hex.stripHexPrefix())
        
        guard let prefixData = (prefix + String(messageData.count)).data(using: .ascii) else {
            throw EthereumKitError.failedToEncode(prefix + String(messageData.count))
        }
        
        let hash = Crypto.hashSHA3_256(prefixData + messageData)
        var signiture = try privateKey.sign(hash: hash)
        
        // Note, the produced signature conforms to the secp256k1 curve R, S and V values,
        // where the V value will be 27 or 28 for legacy reasons.
        signiture[64] += 27
        
        return signiture.toHexString().addHexPrefix()
    }
    
    /// Sign calculates an Ethereum ECDSA signature for: keccack256("\x19Ethereum Signed Message:\n" + len(message) + message))
    /// See also: https://github.com/ethereum/go-ethereum/wiki/Management-APIs#personal_sign
    ///
    /// - Parameter hex: message to sign
    /// - Returns: signiture in hex format
    /// - Throws: EthereumKitError.failedToEncode when failed to encode
    public func sign(message: String) throws -> String {
        return try sign(hex: message.toHexString())
    }
}

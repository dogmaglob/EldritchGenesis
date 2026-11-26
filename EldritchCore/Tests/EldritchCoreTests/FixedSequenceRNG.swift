struct FixedSequenceRNG: RandomNumberGenerator {
    private let sequence: [UInt64]
    private var index: Int

    init(sequence: [UInt64], index: Int) {
        self.sequence = sequence
        self.index = index
    }

    mutating func next() -> UInt64 {
        let value = sequence[index]
        index += 1
        return value
    }
}

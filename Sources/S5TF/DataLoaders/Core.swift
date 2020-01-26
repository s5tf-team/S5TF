import TensorFlow

// MARK: - S5TFBatch
public protocol S5TFBatch {}

public struct S5TFUnlabeledBatch: S5TFBatch {
    public var data: Float

    public init(data: Float) {
        self.data = data
    }
}

public struct S5TFLabeledBatch: S5TFBatch {
    public var data: Tensor<Float>
    public var labels: Tensor<Int32>

    public init(data: Tensor<Float>, labels: Tensor<Int32>) {
        self.data = data
        self.labels = labels
    }
}

// MARK: - S5TFDataLoader
public protocol S5TFDataLoader: Sequence, IteratorProtocol {
    func batched(_ batchSize: Int) -> Self
}

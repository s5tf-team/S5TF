import TensorFlow

// MARK: - S5TFBatch
public protocol S5TFBatch {}
public protocol S5TFLabeledBatch {}

/// A batch of examples for self supervised learning problems.
public struct S5TFUnlabeledBatch: S5TFBatch {
    public var data: Float

    public init(data: Float) {
        self.data = data
    }
}

/// A batch of examples for classification problems.
public struct S5TFCategoricalBatch: S5TFBatch, S5TFLabeledBatch {
    public let data: Tensor<Float>
    public let labels: Tensor<Int32>

    public init(data: Tensor<Float>, labels: Tensor<Int32>) {
        self.data = data
        self.labels = labels
    }
}

/// A batch of examples for regression problems.
public struct S5TFNumericalBatch: S5TFBatch, S5TFLabeledBatch {
    public let data: Tensor<Float>
    public let targets: Tensor<Float>

    public init(data: Tensor<Float>, targets: Tensor<Float>) {
        self.data = data
        self.targets = targets
    }
}

// MARK: - S5TFDataLoader
public protocol S5TFDataLoader: Sequence, IteratorProtocol {
    var batchSize: Int? { get }
    func batched(_ batchSize: Int) -> Self
}

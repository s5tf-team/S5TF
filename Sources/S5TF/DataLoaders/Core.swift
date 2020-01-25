import TensorFlow

// MARK: - S5TFBatch
protocol S5TFBatch {}

public struct S5TFUnlabeledBatch: S5TFBatch {
    var data: Float
}

public struct S5TFLabeledBatch: S5TFBatch {
    var data: Tensor<Float>
    var labels: Tensor<Int32>
}

// MARK: - S5TFDataLoader
protocol S5TFDataLoader: Sequence, IteratorProtocol {
    func batched(_ batchSize: Int) -> Self
}

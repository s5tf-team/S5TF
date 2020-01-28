import Foundation
import TensorFlow

public struct CSVDataLoader: S5TFDataLoader {
    private var index = 0

    public let batchSize: Int?
    private let data: Tensor<Float>
    private let labels: Tensor<Int32>

    public let count: Int
    public let numberOfFeatures: Int

    // MARK: - Initializers.
    private init(data: Tensor<Float>, labels: Tensor<Int32>, batchSize: Int? = nil) {
        guard data.shape.count == 2 else {
            fatalError("Data in CSVLoader should be 2-dimensional, but is \(labels.shape)-dimensional.")
        }
        self.data = data
        self.labels = labels
        self.count = data.shape.dimensions.first!
        self.numberOfFeatures = data.shape.dimensions.last!
        self.batchSize = batchSize
    }

    /// Create a data loader from a comma seperated value (CSV) file.
    ///
    /// - Parameters:
    ///   - fromFileAt fileURL: the url of the csv file.
    ///   - columnNames: the columns of the csv file. If these are supplied, we assume the CSV does not
    ///                  have column names.
    ///   - featureColumnNames: the columns to use as feature names. If this array is empty no feature names
    ///                         will be used and all columns except labelColumnNames will be used as features.
    ///   - labelColumnNames: the name of the columns to use labels. Those will be converted to integers. If no
    ///                       label names are supplied, the `columns` will be used as features, other columns will
    ///                       be labels. If no column names are supplied either, all columns are interpreted
    ///                       as features.
    ///   - batchSize: the batch size. 1 by default.
    public init(fromFileAt fileURL: URL,
                columnNames: [String]? = nil,
                featureColumnNames: [String] = [],
                labelColumnNames: [String] = []) {
        // Validate file exists.
        guard FileManager.default.fileExists(atPath: fileURL.absoluteString) else {
            fatalError("File not found at \(fileURL).")
        }

        // Load data from disk.
        guard let rawData = try? String(contentsOfFile: fileURL.absoluteString) else {
            fatalError("Data at \(fileURL) could not be loaded.")
        }
        var rows = rawData.split(separator: "\n").map(String.init)

        // Get column names.
        let definiteColumnNames: [String]
        if let columnNames = columnNames, !columnNames.isEmpty {
            definiteColumnNames = columnNames
        } else {
            let firstrow = rows[0]
            definiteColumnNames = firstrow.split(separator: ",").map(String.init)
            // Use `.map({String($0)})` because `.map(String.init)` does not compile.
            rows = rows.dropFirst().map({String($0)}) // Drop column row.
        }

        // Make sure featureColumnNames and labelColumnNames are valid.
        guard Set(featureColumnNames).isDisjoint(with: labelColumnNames) else {
            fatalError("Found intersection between featureColumnNames and " +
                "labelColumnNames: \(Set(featureColumnNames).intersection(labelColumnNames)). This is illegal.")
        }

        guard Set(featureColumnNames).isStrictSubset(of: definiteColumnNames) else {
            fatalError("featureColumnNames must be a strict subset of column names.")
        }

        guard Set(labelColumnNames).isStrictSubset(of: definiteColumnNames) else {
            fatalError("labelColumnNames must be a strict subset of column names.")
        }

        let definiteFeatureColumnNames: [String]
        if featureColumnNames.isEmpty {
            definiteFeatureColumnNames = [String](Set(definiteColumnNames).subtracting(labelColumnNames))
        } else { definiteFeatureColumnNames = featureColumnNames }

        // Use a flattened array because Swift does not support 2 dimensional arrays for initialization (yet?).
        var featureValues = [Float]() // TODO: make this dynamic. Probably using a generic parameter.
        var labelValues = [Int32]()

        // Parse CSV.
        let totalNumberOfColumns = rows[0].split(separator: ",").count
        var labels = [String]()
        for (line, row) in rows.enumerated() {
            let items = row.split(separator: ",").map(String.init)

            // Make sure rows are consitent.
            guard items.count <= definiteColumnNames.count else {
                fatalError("Found \(items.count) items on row \(line) while \(definiteColumnNames.count) are needed.")
            }

            guard items.count == totalNumberOfColumns else {
                fatalError("First row had \(totalNumberOfColumns) items but row \(line) has \(items.count) columns.")
            }

            // Load features and labels.
            for (columnIndex, value) in items.enumerated() {
                let column = definiteColumnNames[columnIndex]
                if definiteFeatureColumnNames.contains(column) {
                    // TODO: make Float(...) generic.
                    featureValues.append(Float(value)!)
                } else if labelColumnNames.contains(column) {
                    // TODO: make Float(...) generic.
                    let index = labels.firstIndex(of: value)
                    if let index = index {
                        labelValues.append(Int32(index))
                    } else if let max = labelValues.max() {
                        labelValues.append(max+1)
                        labels.append(value)
                    } else {
                        labelValues.append(0)
                        labels.append(value)
                    }
                }
            }
        }

        // Convert so Swift Tensors and store on self.
        let dataTensor = Tensor<Float>(featureValues)
            .reshaped(to: TensorShape(rows.count, definiteFeatureColumnNames.count))
        let labelsTensor = Tensor<Int32>(labelValues)

        // Initialize self with the loaded data.
        self.init(data: dataTensor, labels: labelsTensor)
    }

    // MARK: Modifiers
    public func batched(_ batchSize: Int) -> CSVDataLoader {
        return CSVDataLoader(data: self.data,
                             labels: self.labels,
                             batchSize: batchSize)
    }

    // MARK: - Iterator
    public mutating func next() -> S5TFLabeledBatch? {
        guard let batchSize = batchSize else {
            fatalError("This data loader does not have a batch size. Set a batch size by calling `.batched(...)`")
        }

        guard index < (count - 1) else {
            return nil
        }

        // Use a partial batch is fewer items than the batch size are available.
        let thisBatchSize = Swift.min(count - index, batchSize)

        // TODO: update with broadcoasting.
        var batchFeatures = [Float]()
        var batchLabels = [Int32]()

        for line in index..<(index + thisBatchSize) {
            for columnIndex in data[line].array {
                batchFeatures.append(columnIndex.scalar!)
            }
            batchLabels.append(labels[line].scalar!)
        }
        let data = Tensor<Float>(batchFeatures).reshaped(to: TensorShape(thisBatchSize, numberOfFeatures))
        let labels = Tensor<Int32>(batchLabels)

        self.index += thisBatchSize

        return S5TFLabeledBatch(data: data, labels: labels)
    }
}

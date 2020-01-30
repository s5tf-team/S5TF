import Foundation
import TensorFlow

public struct CSVDataLoader<Batch: S5TFLabeledBatch>: S5TFDataLoader {
    private var index = 0

    public let batchSize: Int?
    private let csvData: [[String]]
    private let columnNames: [String]
    private let featureColumnNames: [String]
    private let labelColumnNames: [String]

    // `stringEcodedValues` is a dictionary of columns. Each column has a dictionary mapping a label
    // to the corresponding integer label.
    private var stringEcodedValues = [String: [String: Int]]()

    public var count: Int { csvData.count }
    public var numberOfFeatures: Int { featureColumnNames.count }
    public var numberOfLabels: Int { labelColumnNames.count }

    // MARK: - Initializers.
    private init(
        csvData: [[String]],
        columnNames: [String],
        featureColumnNames: [String],
        labelColumnNames: [String],
        batchSize: Int? = nil
    ) {
        self.csvData = csvData
        self.batchSize = batchSize
        self.columnNames = columnNames
        self.featureColumnNames = featureColumnNames
        self.labelColumnNames = labelColumnNames
    }

    /// Create a data loader from a comma seperated value (CSV) file.
    ///
    /// This data loader parses the columns in `featureColumnNames` to Float values. If a value is of type String,
    /// it is encoded to 0, 1, 2, etc. Columns with a header in `labelColumnNames` are used as labels. All labeled
    /// batch types are supported, but strings can only be used with `S5TFCategoricalBatch`. If `S5TFCategoricalBatch`
    /// encounters float values in the label columns, they are converted to Int32.
    ///
    /// - Parameters:
    ///   - fromFileAt fileURL: the url of the csv file.
    ///   - columnNames: the columns of the csv file. If these are supplied, we assume the CSV does not
    ///                  have column names.
    ///   - featureColumnNames: the columns to use as feature names. If this array is empty no feature names
    ///                       will be used and all columns except labelColumnNames will be used as features.
    ///   - labelColumnNames: the name of the columns to use as output. Those will be converted to integers. If no
    ///                        label names are supplied, the `columns` will be used as features, other columns will
    ///                        be labels. If no column names are supplied either, all columns are interpreted
    ///                        as features.
    public init(fromFileAt path: String,
                columnNames: [String]? = nil,
                featureColumnNames: [String] = [],
                labelColumnNames: [String] = []) {
        let (csvData, definiteColumnNames) = S5TFUtils.readCSV(at: path, columnNames: columnNames)

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

        self.init(
            csvData: csvData,
            columnNames: definiteColumnNames,
            featureColumnNames: featureColumnNames,
            labelColumnNames: labelColumnNames
        )
    }

    // MARK: Modifiers
    public func batched(_ batchSize: Int) -> CSVDataLoader {
        return CSVDataLoader(csvData: csvData,
                             columnNames: columnNames,
                             featureColumnNames: featureColumnNames,
                             labelColumnNames: labelColumnNames,
                             batchSize: batchSize)
    }

    // MARK: - Iterator
    public mutating func next() -> Batch? {
        guard let batchSize = batchSize else {
            fatalError("This data loader does not have a batch size. Set a batch size by calling `.batched(...)`")
        }

        guard index <= (count - 1) else {
            return nil
        }

        // Use a partial batch is fewer items than the batch size are available.
        let thisBatchSize = Swift.min(count - index, batchSize)

        var featureValues = [Float]()
        var labelValues: [Float] = []

        for i in index..<index + thisBatchSize {
            let row = csvData[i]

            for (columnIndex, value) in row.enumerated() {
                let column = columnNames[columnIndex]

                // Check whether this column is a feature or label. If none, we continue to the next column.
                if featureColumnNames.contains(column) {
                    if let floatValue = Float(value) {
                        featureValues.append(floatValue)
                    } else {
                        featureValues.append(Float(encode(label: value, inColumn: column)))
                    }
                } else if labelColumnNames.contains(column) {
                    if let batchTypeValue = Float(value) {
                        labelValues.append(batchTypeValue)
                    } else {
                        if Batch.self != S5TFCategoricalBatch.self {
                            fatalError("Found a string on index \(i), but the batch type is \(Batch.self), not " +
                                       "`S5TFCategoricalBatch`. Strings can only be used with categorical batches. " +
                                       "If you are not shuffling, index = line number.")
                        }

                        labelValues.append(Float(encode(label: value, inColumn: column)))
                    }
                }
            }
        }

        // Convert so Swift Tensors and store on self.
        let dataTensor = Tensor<Float>(featureValues)
            .reshaped(to: TensorShape(thisBatchSize, featureColumnNames.count))
        let labelsTensor = Tensor<Float>(labelValues)
            .reshaped(to: TensorShape(thisBatchSize, labelColumnNames.count))

        self.index += thisBatchSize

        if Batch.self == S5TFCategoricalBatch.self {
            let labels = Tensor<Int32>(labelsTensor)
            // swiftlint:disable:next force_cast
            return (S5TFCategoricalBatch(data: dataTensor, labels: labels) as! Batch)
        } else if Batch.self == S5TFNumericalBatch.self {
            // swiftlint:disable:next force_cast
            return (S5TFNumericalBatch(data: dataTensor, targets: labelsTensor) as! Batch)
        } else {
            fatalError("Unsupported batch type \(Batch.self)")
        }
    }

    /// A helper function to encode string labels to indices.
    mutating private func encode(label: String, inColumn column: String) -> Int32 {
        // Encode strings.
        if stringEcodedValues[column] == nil {
            // We have never seen this column.
            stringEcodedValues[column] = [label: 0]
            return 0
        } else if stringEcodedValues[column]![label] == nil {
            // We have never seen this label.
            let max = (stringEcodedValues[column]!.values.max() ?? 0)
            stringEcodedValues[column]![label] = max + 1
            return Int32(max + 1)
        } else {
            return Int32(stringEcodedValues[column]![label]!)
        }
    }
}

import Foundation
import TensorFlow

public struct CSVDataLoader<Batch: S5TFLabeledBatch>: S5TFDataLoader {
    private var index = 0

    public let batchSize: Int?
    private let csvData: [[String]]
    private let columnNames: [String]
    private let inputColumnNames: [String]
    private let outputColumnNames: [String]

    // `stringEcodedValues` is a dictionary of columns. Each column has a dictionary mapping a label
    // to the corresponding integer label.
    private var stringEcodedValues = [String: [String: Int]]()

    public var count: Int { csvData.count }
    public var inputDimensionality: Int { inputColumnNames.count }
    public var outputDimensionality: Int { outputColumnNames.count }

    // MARK: - Initializers.
    private init(
        csvData: [[String]],
        columnNames: [String],
        inputColumnNames: [String],
        outputColumnNames: [String],
        batchSize: Int? = nil
    ) {
        self.csvData = csvData
        self.batchSize = batchSize
        self.columnNames = columnNames
        self.inputColumnNames = inputColumnNames
        self.outputColumnNames = outputColumnNames
    }

    /// Create a data loader from a comma seperated value (CSV) file.
    ///
    /// This data loader parses the columns in `inputColumnNames` to Float values. If a value is of type String,
    /// it is encoded to 0, 1, 2, etc. Columns with a header in `outputColumnNames` are used as outputs. All labeled
    /// batch types are supported, but strings can only be used with `S5TFCategoricalBatch`. If `S5TFCategoricalBatch`
    /// encounters float values in the label columns, they are converted to Int32.
    ///
    /// - Parameters:
    ///   - fromFileAt fileURL: the url of the csv file.
    ///   - columnNames: the columns of the csv file. If these are supplied, we assume the CSV does not
    ///                  have column names.
    ///   - inputColumnNames: the columns to use as feature names. If this array is empty no feature names
    ///                       will be used and all columns except outputColumnNames will be used as features.
    ///   - outputColumnNames: the name of the columns to use as output. Those will be converted to integers. If no
    ///                        label names are supplied, the `columns` will be used as features, other columns will
    ///                        be outputs. If no column names are supplied either, all columns are interpreted
    ///                        as features.
    public init(fromFileAt path: String,
                columnNames: [String]? = nil,
                inputColumnNames: [String] = [],
                outputColumnNames: [String] = []) {
        let (csvData, definiteColumnNames) = S5TFUtils.readCSV(at: path, columnNames: columnNames)

        guard Set(inputColumnNames).isDisjoint(with: outputColumnNames) else {
            fatalError("Found intersection between inputColumnNames and " +
                "outputColumnNames: \(Set(inputColumnNames).intersection(outputColumnNames)). This is illegal.")
        }

        guard Set(inputColumnNames).isStrictSubset(of: definiteColumnNames) else {
            fatalError("inputColumnNames must be a strict subset of column names.")
        }

        guard Set(outputColumnNames).isStrictSubset(of: definiteColumnNames) else {
            fatalError("outputColumnNames must be a strict subset of column names.")
        }

        self.init(
            csvData: csvData,
            columnNames: definiteColumnNames,
            inputColumnNames: inputColumnNames,
            outputColumnNames: outputColumnNames
        )
    }

    // MARK: Modifiers
    public func batched(_ batchSize: Int) -> CSVDataLoader {
        return CSVDataLoader(csvData: csvData,
                             columnNames: columnNames,
                             inputColumnNames: inputColumnNames,
                             outputColumnNames: outputColumnNames,
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

        let (inputValues, outputValues) = encode(
            rows: [[String]](csvData[index..<index + thisBatchSize]),
            startIndex: index,
            inputColumnNames: inputColumnNames,
            outputColumnNames: outputColumnNames)

        // Convert so Swift Tensors and store on self.
        let inputTensor = Tensor<Float>(inputValues)
            .reshaped(to: TensorShape(thisBatchSize, inputColumnNames.count))
        let outputTensor = Tensor<Float>(outputValues)
            .reshaped(to: TensorShape(thisBatchSize, outputColumnNames.count))

        self.index += thisBatchSize

        if Batch.self == S5TFCategoricalBatch.self {
            let labels = Tensor<Int32>(outputTensor)
            // swiftlint:disable:next force_cast
            return (S5TFCategoricalBatch(data: inputTensor, labels: labels) as! Batch)
        } else if Batch.self == S5TFNumericalBatch.self {
            // swiftlint:disable:next force_cast
            return (S5TFNumericalBatch(data: inputTensor, targets: outputTensor) as! Batch)
        } else {
            fatalError("Unsupported batch type \(Batch.self)")
        }
    }

    /// Encode CSV rows to input and output values, of type [float].
    ///
    /// - Paramters:
    ///   - rows: The rows to encode
    ///   - startIndex: The line number, or index, of the first row in rows
    ///   - inputColumnNames: The names of the columns to use as input
    ///   - outputColumnNames: The names of the columns to use as output
    ///
    /// - Returns:
    ///   - input: The encoded input values. Flattended.
    ///   - output: The encoded output values. Flattended.
    private mutating func encode(
        rows: [[String]],
        startIndex: Int,
        inputColumnNames: [String],
        outputColumnNames: [String]
    ) -> (input: [Float], output: [Float]) {
        var inputValues = [Float]()
        var outputValues = [Float]()

        for (index, row) in rows.enumerated() {
            for (columnIndex, value) in row.enumerated() {
                let column = columnNames[columnIndex]

                // Check whether this column is an input or output. If none, we continue to the next column.
                if inputColumnNames.contains(column) {
                    if let floatValue = Float(value) {
                        inputValues.append(floatValue)
                    } else {
                        inputValues.append(Float(encode(label: value, inColumn: column)))
                    }
                } else if outputColumnNames.contains(column) {
                    if let batchTypeValue = Float(value) {
                        outputValues.append(batchTypeValue)
                    } else {
                        if Batch.self != S5TFCategoricalBatch.self {
                            fatalError("Found a string on index \(index + startIndex), but the batch type is " +
                                       "\(Batch.self) , not `S5TFCategoricalBatch`. Strings can only be " +
                                       " used with categorical batches. If you are not shuffling, index = line number.")
                        }

                        outputValues.append(Float(encode(label: value, inColumn: column)))
                    }
                }
            }
        }

        return (inputValues, outputValues)
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
            let max = stringEcodedValues[column]!.values.max() ?? 0
            stringEcodedValues[column]![label] = max + 1
            return Int32(max + 1)
        } else {
            return Int32(stringEcodedValues[column]![label]!)
        }
    }
}

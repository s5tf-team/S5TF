# S5TF

S5TF general helper utilities

## Concepts

### DataLoaders
Data loaders are objects that load data and make it iterable in mini batches. It is possible to create a custom data loader tailored for your specific needs or you can use one of the default data loaders available:

* [CSVDataLoader](/Sources/S5TF/DataLoaders/CSVDataLoader.swift)

An example of using a data loader (inspired by [UCI Iris](http://archive.ics.uci.edu/ml/datasets/Iris)):

```swift
let dataLoader = CSVDataLoader(fromFileAt: URL(string: "~/.s5tf-datasets/iris/iris.csv")!,
                               columnNames: ["sepal length in cm",
                                             "sepal width",
                                             "petal length",
                                             "petal width",
                                             "species"],
                               featureColumnNames: ["sepal length in cm",
                                                    "sepal width",
                                                    "petal length",
                                                    "petal width"],
                               labelColumnNames: ["species"])

for batch in dataLoader.batched(32) {
    print(batch.data, batch.labels)
}
```

Check out [s5tf-team/datasets](https://github.com/s5tf-team/datasets) for predefined data loaders for a selection of public datasets.

## Contributing ❤️
Thanks for even considering contributing.

Make sure to run [`swiftlint`](https://github.com/realm/SwiftLint) on your code. If you are not sure about how to format something, refer to the [Google Swift Style Guide](https://google.github.io/swift/).

Please link to the completed GitHub Actions `build` test in your fork with your PR.

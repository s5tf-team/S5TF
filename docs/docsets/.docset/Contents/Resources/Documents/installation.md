# Installation

This guide shows how to install S5TF.

## Google Colab
The preferred way to use this repository is through Google Colab. Run the following code in the first cell:

```swift
%install-location $cwd/swift-install
%install '.package(url: "https://github.com/s5tf-team/S5TF", .branch("master"))' S5TF
```

## Swift Package
To use this repository in a project you can use the Swift Package Manager.

Add the following line to `dependencies` in your `Package.swift` file:

```swift
.package(url: "https://github.com/s5tf-team/S5TF", .branch("master"))
```

Then add `"S5TF"` as a dependency to a target:

```swift
dependencies: ["S5TF"]
```

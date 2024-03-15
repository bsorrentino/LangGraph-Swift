# LangGraph for Swift
🚀 LangGraph for Swift. A library for building stateful, multi-actor applications with LLMs, built on top of [LangChain-Swift]. 
> It is a porting of original [LangGraph] from [LangChain AI project][langchain.ai] in Swift fashion


## Adding LangGraph for Swift as a Dependency

To use the LangGraph for Swift library in a [SwiftPM] project, add the following line to the dependencies in your `Package.swift` file:

```Swift
.package(url: "https://github.com/bsorrentino/LangGraph-Swift.git", from: "1.0.0"),
```
Include `LangGraph` as a dependency for your executable target:

```Swift
.target(name: "<target>", dependencies: [
    .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
]),
```

Finally, add `import LangGraph` to your source code.




[SwiftPM]: https://www.swift.org/documentation/package-manager/
[langchain-swift]: https://github.com/buhe/langchain-swift.git
[langchain.ai]: https://github.com/langchain-ai
[langgraph]: https://github.com/langchain-ai/langgraph
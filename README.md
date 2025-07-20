# LangGraph for Swift

![SwiftPM](https://img.shields.io/badge/SwiftPM-Compatible-green) ![GitHub tag (latest by semver)](https://img.shields.io/github/v/tag/bsorrentino/LangGraph-Swift?sort=semver) [![DocC](https://img.shields.io/badge/DocC-Documentation-blue)][docc] 


🚀 LangGraph for Swift. A library for building stateful, multi-actor applications with LLMs, developed to work with [LangChain-Swift]. 
> It is a porting of original [LangGraph] from [LangChain AI project][langchain.ai] in Swift fashion

## Features

- [x] StateGraph
- [x] Nodes
- [x] Edges
- [x] Conditional Edges
- [x] Entry Points
- [x] Conditional Entry Points
- [x] State
  - [x] Schema (_a series of Channels_)
    - [x] Reducer (_how apply  updates to the state attributes_)
    - [x] Default provider
    - [x] AppenderChannel (_values accumulator_)
- [x] Compiling graph    
- [x] Async support 
- [x] Streaming support 
- [x] Subgraph support 
- [x] Checkpoints (_save and replay feature_)
    - [x] Threads (_checkpointing of multiple different runs_)
    - [x] Update state (_interact with the state directly and update it_)
    - [x] Breakpoints (_pause and resume feature_)
- [ ] Graph visualization
  - [ ] [PlantUML]
  - [ ] [Mermaid]

## Quick Start 

### Adding LangGraph for Swift as a Dependency

To use the LangGraph for Swift library in a [SwiftPM] project, add the following line to the dependencies in your `Package.swift` file:

```Swift
.package(url: "https://github.com/bsorrentino/LangGraph-Swift.git", from: "<last version>"),
```
Include `LangGraph` as a dependency for your executable target:

```Swift
.target(name: "<target>", dependencies: [
    .product(name: "LangGraph", package: "LangGraph-Swift"),
]),
```

Finally, add `import LangGraph` to your source code.

### Define the agent state

The main type of graph in `langgraph` is the `StatefulGraph`. This graph is parameterized by a state object that it passes around to each node. Each node then returns operations to update that state. These operations can either SET specific attributes on the state (e.g. overwrite the existing values) or ADD to the existing attribute. Whether to set or add is denoted by initialize the property with a `AppendableValue`. The State must be compliant with `AgentState` protocol that essentially is a Dictionary wrapper

```Swift
public protocol AgentState {
    
    var data: [String: Any] { get }
    
    init( _ initState: [String: Any] )
}
```

### Define the nodes

We now need to define a few different nodes in our graph. In langgraph, a node is a function that accept an `AgentState` as argument. There are two main nodes we need for this:

1. **The agent**: responsible for deciding what (if any) actions to take.
1. **A function to invoke tools**: if the agent decides to take an action, this node will then execute that action.

### Define Edges

We will also need to define some edges. Some of these edges may be conditional. The reason they are conditional is that based on the output of a node, one of several paths may be taken. The path that is taken is not known until that node is run (the LLM decides).

1. **Conditional Edge**: after the agent is called, we should either:
    * If the agent said to take an action, then the function to invoke tools should be called
    * If the agent said that it was finished, then it should finish
1. **Normal Edge**: after the tools are invoked, it should always go back to the agent to decide what to do next

### Define the graph

We can now put it all together and define the graph! (see example below)

## Integrate with LangChain for Swift

In the [LangChainDemo](LangChainDemo) project, you can find the porting of [AgentExecutor] from [LangChain Swift project][langchain.ai] using LangGraph. Below you can find a piece of code of the `AgentExecutor` to give you an idea of how to use it.


```Swift

    struct AgentExecutorState : AgentState {

        // describes the properties that have particular Reducer related function
        // AppenderChannel<T> is a built-in channel that manage array of values
        static var schema: Channels = {
            [
                "intermediate_steps": AppenderChannel<(AgentAction, String)>(),
                "chat_history": AppenderChannel<BaseMessage>(),
            ]
        }()

        var data: [String : Any]
        
        init(_ initState: [String : Any]) {
            data = initState
        }

        // from langchain
        var input:String? {
            value("input")
        }
        var chatHistory:[BaseMessage]? {
            value("chat_history" )
        }
        var agentOutcome:AgentOutcome? {
            value("agent_outcome")
        }     
        var intermediate_steps: [(AgentAction, String)]? {
            value("intermediate_steps" )
        }   
    }


    let workflow = StateGraph( channels: AgentExecutorState.schema ) {
        AgentExecutorState( $0 )
    }
        
    try workflow.addNode("call_agent" ) { state in
        
        guard let input = state.input else {
            throw CompiledGraphError.executionError("'input' argument not found in state!")
        }
        guard let intermediate_steps = state.intermediate_steps else {
            throw CompiledGraphError.executionError("'intermediate_steps' property not found in state!")
        }

        let step = await agent.plan(input: input, intermediate_steps: intermediate_steps)
        switch( step ) {
        case .finish( let finish ):
            return [ "agent_outcome": AgentOutcome.finish(finish) ]
        case .action( let action ):
            return [ "agent_outcome": AgentOutcome.action(action) ]
        default:
            throw CompiledGraphError.executionError( "Parsed.error" )
        }
    }

    try workflow.addNode("call_action" ) { state in
        
        guard let agentOutcome = state.agentOutcome else {
            throw CompiledGraphError.executionError("'agent_outcome' property not found in state!")
        }
        guard case .action(let action) = agentOutcome else {
            throw CompiledGraphError.executionError("'agent_outcome' is not an action!")
        }
        let result = try await toolExecutor( action )
        return [ "intermediate_steps" : (action, result) ]
    }

    try workflow.addEdge(sourceId: START, targetId: "call_agent")

    try workflow.addConditionalEdge( sourceId: "call_agent", condition: { state in
        
        guard let agentOutcome = state.agentOutcome else {
            throw CompiledGraphError.executionError("'agent_outcome' property not found in state!")
        }

        switch agentOutcome {
        case .finish:
            return "finish"
        case .action:
            return "continue"
        }

    }, edgeMapping: [
        "continue" : "call_action",
        "finish": END])

    try workflow.addEdge(sourceId: "call_action", targetId: "call_agent")

    let app = try workflow.compile()
    
    let result = try await app.invoke(inputs: .args([ "input": input, "chat_history": [] ]) )
    
    print( result )

```

## User interruptions

LangGraph support pause and resume of execution. You must provide a `CheckpointSaver` through `CompileConfig` and a `ThreadId`(aka Session) through `RunnableConfig` to enable it. Below an example

```swift

// Create a memory-based checkpoint saver
let saver = MemoryCheckpointSaver()

// Build the workflow with an initial state
let workflow = try StateGraph { BinaryOpState($0) }

// Add node "agent_1" that returns "add1": 37
.addNode("agent_1") { state in
    print( "agent_1", state )
    return ["add1": 37]
}
// Add node "agent_2" that returns "add2": 10
.addNode("agent_2") { state in
    print( "agent_2", state )
    return ["add2": 10]
}
// Add node "sum" that sums add1 and add2
.addNode("sum") { state in
    print( "sum", state )
    guard let add1 = state.add1, let add2 = state.add2 else {
        throw CompiledGraphError.executionError("agent state is not valid! expect 'add1', 'add2'")
    }
    return ["result": add1 + add2 ]
}
// Define the edges between nodes
.addEdge(sourceId: "agent_1", targetId: "agent_2")
.addEdge(sourceId: "agent_2", targetId: "sum")
.addEdge( sourceId: START, targetId: "agent_1")
.addEdge(sourceId: "sum", targetId: END )

// Compile the workflow, instructing it to interrupt before executing "sum"
let app = try workflow.compile( config: CompileConfig(checkpointSaver: saver, interruptionsBefore: ["sum"]) )

// Start a new run in a different thread 
let runnableConfig = RunnableConfig( threadId: "T1" )

let initValue:( lastState:BinaryOpState?, nodes:[String]) = ( nil, [] )

let result = try await app.stream( .args([:]), config: runnableConfig ).reduce( initValue, { partialResult, output in
    print( output )
    return ( output.state,  partialResult.1 + [output.node ] )
})

// This run is also interrupted before "sum"
#expect( dictionaryOfAnyEqual(  ["add1": 37, "add2": 10 ], result.lastState!.data) )

// Resume the third run with updated state: change add2 from 10 to 13
let lastCheckpoint2 = try #require( saver.last( config: runnableConfig ) )
var runnableConfig2 = runnableConfig.with { $0.checkpointId = lastCheckpoint2.id }
runnableConfig2 = try await app.updateState(config: runnableConfig2, values: ["add2": 13] )

// Resume and complete execution with updated value
let initValue2:( lastState:BinaryOpState?, nodes:[String]) = ( nil, [] )
let result2 = try await app.stream( .resume, config: runnableConfig2 ).reduce( initValue2, { partialResult, output in
    print( output )
    return ( output.state,  partialResult.1 + [output.node ] )
})

// Verify that "result" now reflects the updated input
#expect( dictionaryOfAnyEqual(  ["add1": 37, "add2": 13, "result": 50 ], result2.lastState!.data) )

```



# References

* [AI Agent on iOS with LangGraph for Swift](https://dev.to/bsorrentino/ai-agent-on-ios-with-langgraph-for-swift-1740)

[docc]: https://bsorrentino.github.io/LangGraph-Swift/documentation/langgraph/
[article1]: https://dev.to/bsorrentino/ai-agent-on-ios-with-langgraph-for-swift-1740
[SwiftPM]: https://www.swift.org/documentation/package-manager/
[langchain-swift]: https://github.com/buhe/langchain-swift.git
[langchain.ai]: https://github.com/langchain-ai
[langgraph]: https://github.com/langchain-ai/langgraph
[AgentExecutor]: https://github.com/buhe/langchain-swift/blob/main/Sources/LangChain/agents/Agent.swift
[PlantUML]: https://plantuml.com
[Mermaid]: https://mermaid.js.org

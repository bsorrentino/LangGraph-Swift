# LangGraph for Swift
🚀 LangGraph for Swift. A library for building stateful, multi-actor applications with LLMs, developed to work with [LangChain-Swift]. 
> It is a porting of original [LangGraph] from [LangChain AI project][langchain.ai] in Swift fashion

## Quick Start 

### Adding LangGraph for Swift as a Dependency

To use the LangGraph for Swift library in a [SwiftPM] project, add the following line to the dependencies in your `Package.swift` file:

```Swift
.package(url: "https://github.com/bsorrentino/LangGraph-Swift.git", from: "1.0.0"),
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
        var data: [String : Any]
        
        init() {
            self.init([
                "intermediate_steps": AppendableValue(),
                "chat_history": AppendableValue()
            ])
        }
        
        init(_ initState: [String : Any]) {
            data = initState
        }

        // from langchain
        var input:String? {
            value("input")
        }
        var chatHistory:[BaseMessage]? {
            appendableValue("chat_history" )
        }
        var agentOutcome:AgentOutcome? {
            return value("agent_outcome")
        }     
        var intermediate_steps: [(AgentAction, String)]? {
            appendableValue("intermediate_steps" )
        }   
    }


    let workflow = GraphState {
        AgentExecutorState()
    }
    
    try workflow.addNode("call_agent" ) { state in
        
        guard let input = state.input else {
            throw GraphRunnerError.executionError("'input' argument not found in state!")
        }
        guard let intermediate_steps = state.intermediate_steps else {
            throw GraphRunnerError.executionError("'intermediate_steps' property not found in state!")
        }

        let step = await agent.plan(input: input, intermediate_steps: intermediate_steps)
        switch( step ) {
        case .finish( let finish ):
            return [ "agent_outcome": AgentOutcome.finish(finish) ]
        case .action( let action ):
            return [ "agent_outcome": AgentOutcome.action(action) ]
        default:
            throw GraphRunnerError.executionError( "Parsed.error" )
        }
    }

    try workflow.addNode("call_action" ) { state in
        
        guard let agentOutcome = state.agentOutcome else {
            throw GraphRunnerError.executionError("'agent_outcome' property not found in state!")
        }
        guard case .action(let action) = agentOutcome else {
            throw GraphRunnerError.executionError("'agent_outcome' is not an action!")
        }
        let result = try await toolExecutor( action )
        return [ "intermediate_steps" : (action, result) ]
    }

    try workflow.setEntryPoint("call_agent")
    
    try workflow.addConditionalEdge( sourceId: "call_agent", condition: { state in
        
        guard let agentOutcome = state.agentOutcome else {
            throw GraphRunnerError.executionError("'agent_outcome' property not found in state!")
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

    let runner = try workflow.compile()
    
    let result = try await runner.invoke(inputs: [ "input": input, "chat_history": [] ])
    
    print( result )

```

# References

* [AI Agent on iOS with LangGraph for Swift](https://dev.to/bsorrentino/ai-agent-on-ios-with-langgraph-for-swift-1740)


[article1]: https://dev.to/bsorrentino/ai-agent-on-ios-with-langgraph-for-swift-1740
[SwiftPM]: https://www.swift.org/documentation/package-manager/
[langchain-swift]: https://github.com/buhe/langchain-swift.git
[langchain.ai]: https://github.com/langchain-ai
[langgraph]: https://github.com/langchain-ai/langgraph
[AgentExecutor]: https://github.com/buhe/langchain-swift/blob/main/Sources/LangChain/agents/Agent.swift
# LangGraph for Swift
🚀 LangGraph for Swift. A library for building stateful, multi-actor applications with LLMs, developed to work with [LangChain-Swift]. 
> It is a porting of original [LangGraph] from [LangChain AI project][langchain.ai] in Swift fashion


## Adding LangGraph for Swift as a Dependency

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



[SwiftPM]: https://www.swift.org/documentation/package-manager/
[langchain-swift]: https://github.com/buhe/langchain-swift.git
[langchain.ai]: https://github.com/langchain-ai
[langgraph]: https://github.com/langchain-ai/langgraph
[AgentExecutor]: https://github.com/buhe/langchain-swift/blob/main/Sources/LangChain/agents/Agent.swift
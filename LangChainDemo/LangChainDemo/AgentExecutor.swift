//
//  AgentExecutor.swift
//  LangChainDemo
//
//  Created by bsorrentino on 14/03/24.
//

import Foundation
import LangChain
import LangGraph

enum AgentOutcome /* Union */ {
    case action(AgentAction)
    case finish(AgentFinish)
}


struct AgentExecutorState : AgentState {
    var data: [String : Any]
    
    init() {
        self.init([
            "intermediate_steps": AppendableValue<(AgentAction, String)>(),
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
    
    // Tracing
    var start:Double? {
        value("start")
    }
    var cost:Double? {
        value("cost")
    }
}

struct ToolOutputParser: BaseOutputParser {
    public init() {}
    public func parse(text: String) -> Parsed {
        print(text.uppercased())
        let pattern = "Action\\s*:[\\s]*(.*)[\\s]*Action\\s*Input\\s*:[\\s]*(.*)"
        let regex = try! NSRegularExpression(pattern: pattern)
        
        if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
            
            let firstCaptureGroup = Range(match.range(at: 1), in: text).map { String(text[$0]) }
//            print(firstCaptureGroup!)
            
            
            let secondCaptureGroup = Range(match.range(at: 2), in: text).map { String(text[$0]) }
//            print(secondCaptureGroup!)
            return Parsed.action(AgentAction(action: firstCaptureGroup!, input: secondCaptureGroup!, log: text))
        } else {
            if text.uppercased().contains(FINAL_ANSWER_ACTION) {
                return Parsed.finish(AgentFinish(final: text))
            }
            return Parsed.error
        }
    }
}

public func runAgent( input: String, llm: LLM, tools: [BaseTool], callbacks: [BaseCallbackHandler] = []) async throws -> Void {
    
    
    let AGENT_REQ_ID = "agent_req_id"
    
    let agent_reqId = UUID().uuidString
        
    let agent = {
        let output_parser = ToolOutputParser()
        let llm_chain = LLMChain(llm: llm,
                                 prompt: ZeroShotAgent.create_prompt(tools: tools),
                                 parser: output_parser,
                                 stop: ["\nObservation: ", "\n\tObservation: "])
        return ZeroShotAgent(llm_chain: llm_chain)

    }()
    
    let toolExecutor = {  (action: AgentAction) in
        guard let tool = tools.filter({$0.name() == action.action}).first else {
            throw CompiledGraphError.executionError("tool \(action.action) not found!")
        }

        do {

            print("try call \(tool.name()) tool.")
            var observation = try await tool.run(args: action.input)
            if observation.count > 1000 {
                observation = String(observation.prefix(1000))
            }
            return observation
        } catch {
            print("\(error.localizedDescription) at run \(tool.name()) tool.")
            let observation = try! await InvalidTool(tool_name: tool.name()).run(args: action.input)
            return observation
        }

    }
        

    let  onAgentStart = { (input: String ) in
        do {
            for callback in callbacks {
                try callback.on_agent_start(prompt: input, metadata: [AGENT_REQ_ID: agent_reqId])
            }
        } catch {
            print( "call on_agent_start callback error: \(error)")
        }
    }

    let onAgentAction = { (action: AgentAction ) in
        do {
            for callback in callbacks {
                try callback.on_agent_action(action: action, metadata: [AGENT_REQ_ID: agent_reqId])
            }
        } catch {
            print( "call on_agent_action callback error: \(error)")
        }
        
    }
    
    let onAgentFinish = { (action: AgentFinish ) in
        do {
            for callback in callbacks {
                try callback.on_agent_finish(action: action, metadata: [AGENT_REQ_ID: agent_reqId])
            }
        } catch {
            print( "call on_agent_finish callback error: \(error)")
        }
    }

    
    let workflow = StateGraph {
        AgentExecutorState()
    }
    
    try workflow.addNode( "call_start" ) { state in

        ["start": Date.now.timeIntervalSince1970]
    }
    
    try workflow.addNode( "call_end" ) { state in
         
        var cost:Double = 0

        if let start = state.start {
            cost = Date.now.timeIntervalSince1970 - start
            
        }
        
        return [ "cost": cost ]
    }

    try workflow.addNode("call_agent" ) { state in
        
        guard let input = state.input else {
            throw CompiledGraphError.executionError("'input' argument not found in state!")
        }
        guard let intermediate_steps = state.intermediate_steps else {
            throw CompiledGraphError.executionError("'intermediate_steps' property not found in state!")
        }

        onAgentStart( input )
        let step = await agent.plan(input: input, intermediate_steps: intermediate_steps)
        switch( step ) {
        case .finish( let finish ):
            onAgentFinish( finish )
            return [ "agent_outcome": AgentOutcome.finish(finish) ]
        case .action( let action ):
            onAgentAction( action )
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

    try workflow.setEntryPoint("call_start")
    workflow.setFinishPoint("call_end")
    
    try workflow.addEdge(sourceId: "call_start", targetId: "call_agent")
    try workflow.addEdge(sourceId: "call_action", targetId: "call_agent")
    try workflow.addConditionalEdge( sourceId: "call_agent", condition: { state in
        
        guard let agentOutcome = state.agentOutcome else {
            throw CompiledGraphError.executionError("'agent_outcome' property not found in state!")
        }

        return switch agentOutcome {
            case .finish:
                "finish"
            case .action:
                "continue"
            }

    }, edgeMapping: [
        "continue" : "call_action",
        "finish": "call_end"])
    
    
    let runner = try workflow.compile()
    
    for try await result in runner.stream(inputs: [ "input": input, "chat_history": [] ]) {
        print( "-------------")
        print( "Agent Output of \(result.node)" )
        print( result.state )
    }
    print( "-------------")

}

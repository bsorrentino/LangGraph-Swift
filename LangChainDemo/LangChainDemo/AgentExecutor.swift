//
//  AgentExecutor.swift
//  LangChainDemo
//
//  Created by bsorrentino on 14/03/24.
//

import Foundation
import LangChain
import LangGraph

struct AgentExecutorState : AgentState {
    var data: [String : Any]
    
    init() {
        data = ["intermediate_steps": AppendableValue()]
    }
    
    init(_ initState: [String : Any]) {
        data = initState
    }
    
    var start:Double? {
        value("start")
    }
    var input:String? {
        value("input")
    }
    
    var output:(LLMResult, Parsed)? {
        value("output")
    }

    var intermediate_steps: [(AgentAction, String)]? {
        appendableValue("intermediate_steps" )
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
    
    let output_parser = ToolOutputParser()
    let llm_chain = LLMChain(llm: llm,
                             prompt: ZeroShotAgent.create_prompt(tools: tools),
                             parser: output_parser,
                             stop: ["\nObservation: ", "\n\tObservation: "])
    let agent = ZeroShotAgent(llm_chain: llm_chain)
    
    let AGENT_REQ_ID = "agent_req_id"
    
    let chain_reqId = UUID().uuidString

    func take_next_step( input: String, intermediate_steps: [(AgentAction, String)]) async -> (Parsed, String) {
        let step = await agent.plan(input: input, intermediate_steps: intermediate_steps)
        switch step {
        case .finish(let finish):
            return (step, finish.final)
        case .action(let action):
            let tool = tools.filter{$0.name() == action.action}.first!
            do {
                print("try call \(tool.name()) tool.")
                var observation = try await tool.run(args: action.input)
                if observation.count > 1000 {
                    observation = String(observation.prefix(1000))
                }
                return (step, observation)
            } catch {
                print("\(error.localizedDescription) at run \(tool.name()) tool.")
                let observation = try! await InvalidTool(tool_name: tool.name()).run(args: action.input)
                return (step, observation)
            }
        default:
            return (step, "fail")
        }
    }
    
    
    func callEnd(output: String, reqId: String, cost: Double) {
        for callback in callbacks {
            do {
                try callback.on_chain_end(output: output, metadata: [DefaultChain.CHAIN_REQ_ID_KEY: reqId, DefaultChain.CHAIN_COST_KEY: "\(cost)"])
            } catch {
                print("call chain end callback errer: \(error)")
            }
        }
    }
    
    func callStart(prompt: String, reqId: String) {
        for callback in callbacks {
            do {
                try callback.on_chain_start(prompts: prompt, metadata: [DefaultChain.CHAIN_REQ_ID_KEY: reqId])
            } catch {
                print("call chain end callback errer: \(error)")
            }
        }
    }
    
    func callCatch(error: Error, reqId: String, cost: Double) {
        for callback in callbacks {
            do {
                try callback.on_chain_error(error: error, metadata: [DefaultChain.CHAIN_REQ_ID_KEY: reqId, DefaultChain.CHAIN_COST_KEY: "\(cost)"])
            } catch {
                print("call LLM start callback errer: \(error)")
            }
        }
    }

    let workflow = GraphState( stateType: AgentExecutorState.self )
    
    try workflow.addNode( "call_start" ) { state in

        guard let prompt = state.input else {
            throw GraphRunnerError.executionError("'inputs' argument not found!")
        }
        
        callStart(prompt: prompt, reqId: chain_reqId)
        
        return ["start": Date.now.timeIntervalSince1970]
    }
    
    try workflow.addNode( "call_end" ) { state in
         
        guard let output = state.output else {
            throw GraphRunnerError.executionError("'output' argument not found!")
        }
        guard let start = state.start else {
            throw GraphRunnerError.executionError("'start' argument not found!")
        }

        let cost = Date.now.timeIntervalSince1970 - start

        
        callEnd(output: output.0.llm_output ?? "", reqId: chain_reqId, cost: cost)
        
        return [:]
    }

    try workflow.addNode("call_agent" ) { state in
        
        guard let input = state.input else {
            throw GraphRunnerError.executionError("'inputs' argument not found in state!")
        }
        guard let intermediate_steps = state.intermediate_steps else {
            throw GraphRunnerError.executionError("'intermediate_steps' property not found in state!")
        }

        let agent_reqId = UUID().uuidString
        do {
            for callback in callbacks {
                try callback.on_agent_start(prompt: input, metadata: [AGENT_REQ_ID: agent_reqId])
            }
        } catch {
            print( "call agent start callback error: \(error)")
        }

        let result = await take_next_step(input: input, intermediate_steps: intermediate_steps)
        
        switch result.0 {
        case .finish(let finish):
            print("Found final answer.")
            do {
                for callback in callbacks {
                    try callback.on_agent_finish(action: finish, metadata: [AGENT_REQ_ID: agent_reqId])
                }
            } catch {
                print( "call chain end callback error: \(error)")
            }
            return [ "output": (LLMResult(llm_output: result.1), Parsed.str(result.1)) ]
        case .action(let action):
                do {
                    for callback in callbacks {
                        try callback.on_agent_action(action: action, metadata: [AGENT_REQ_ID: agent_reqId])
                    }
                } catch {
                    print( "call chain end callback error: \(error)")
                }
            return [ "intermediate_steps" : (action, result.1) ]
        default:
            throw GraphRunnerError.executionError( "Parsed.error" )
        }
    }
    
    try workflow.setEntryPoint("call_start")
    workflow.setFinishPoint("call_end")
    
    try workflow.addEdge(sourceId: "call_start", targetId: "call_agent")
    try workflow.addConditionalEdge( sourceId: "call_agent", condition: { state in
        return "terminate"
    }, edgeMapping: [
        "continue" : "call_agent",
        "terminate": "call_end"])
    
    
    let runner = try workflow.compile()
    
    let result = try await runner.invoke(inputs: [ "input": input ])
    
    print( result )
}

//
//  Issue10Tests.swift
//  LangGraph
//
//  Created by bsorrentino on 30/07/25.
//

@testable import LangGraph
import XCTest
import Testing

struct ChatHistory : Codable {
  var message: String
  var id: UUID
}

struct MyState: AgentState {
    var data: [String : Any]
    
    init(_ initState: [String : Any]) {
        data = initState
    }
    
    var chat_history: [ChatHistory] {
        value("chat_history")!
    }
    
    var last_chat: ChatHistory? {
        return value("last_chat")
    }
}

@Test
func testIssue10() async throws {
    
    let saver = MemoryCheckpointSaver()
    
    // Build the workflow with an initial state
    let workflow = try StateGraph( channels: ["chat_history": AppenderChannel<ChatHistory>()]) { MyState($0) }
    
    // Add node "agent_1" that returns "add1": 37
    .addNode("agent_1") { state in
        print( "agent_1", state )
        return ["chat_history": [ ChatHistory(message: "message1", id: UUID())] ]
    }
    // Add node "agent_2" that returns "add2": 10
    .addNode("agent_2") { state in
        print( "agent_2", state )
        return ["chat_history": [ChatHistory(message: "message2", id: UUID())] ]
    }
    // Define the edges between nodes
    .addEdge( sourceId: START, targetId: "agent_1")
    .addEdge(sourceId: "agent_1", targetId: "agent_2")
    .addEdge(sourceId: "agent_2", targetId: END)
    
    let app = try workflow.compile( config: CompileConfig( checkpointSaver: saver,
                                                           interruptionsBefore: ["agent_2"] ) )
    
    let runnableConfig = RunnableConfig()
    
    var initValue:( lastState:MyState?, nodes:[String]) = ( nil, [] )
    
    // Start workflow execution — it will stop before running "sum"
    var result = try await app.stream( .args([:]), config: runnableConfig )
        .reduce( initValue, { partialResult, output in
            print( output )
            return ( output.state,  partialResult.1 + [output.node ] )
        })
  
    var resultState = try #require(result.lastState)
    
    #expect( resultState.data.count == 1 )
    #expect( resultState.chat_history.count == 1 )

    let runnableConfig2 = try await app.updateState(config: runnableConfig,
                                                    values: [
                                                        "chat_history": [ ChatHistory(message: "message3", id: UUID()) ],
                                                        "last_chat": ChatHistory(message: "message3.1", id: UUID())
                                                    ]
    )

    initValue = ( nil, [] )
    
    // Start workflow execution — it will stop before running "sum"
    result = try await app.stream( .resume, config: runnableConfig2 )
            .reduce( initValue, { partialResult, output in
                print( output )
                return ( output.state,  partialResult.1 + [output.node ] )
            })
    
    resultState = try #require(result.lastState)
    
    #expect( resultState.data.count == 2 )
    #expect( resultState.chat_history.count == 3 )
    let last_chat = try #require( resultState.last_chat )
    #expect( last_chat.message == "message3.1" )
}

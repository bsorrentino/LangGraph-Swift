//
//  ContentView.swift
//  LangChainDemo
//
//  Created by bsorrentino on 14/03/24.
//

import SwiftUI
import LangChain
import OpenAIKit
import AsyncHTTPClient

class Callback : BaseCallbackHandler {
    
    override func on_tool_start(tool: BaseTool, input: String, metadata: [String: String]) throws {
        
        print( "on_tool_start", tool.name())
    }
}

struct ContentView: View {
    
    @State var openai_api_key: String = "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"
    @State var input:String = "perform a test call"
    @State var progress: String = ""
    
    var body: some View {
        VStack(alignment: .center) {
            
            TextField(text: $openai_api_key,
                      label: { Label("OPENAI API KEY", systemImage: "bolt.fill") })
            Divider()
            
            TextField(text: $input,
                      label: { Label("PROMPT", systemImage: "bolt.fill") })

            Button( action: executeAgent, label: {
                Label("EXECUTE", systemImage: "bolt.fill")
            })
            Divider()
            Text( progress )
        }
        .padding()
    }
    
    @MainActor
    func setProgress( _ msg: String ) {
        progress = msg
    }
    
    func executeAgent() {
        Env.initSet(["OPENAI_API_KEY": openai_api_key])
        
        Task {
            do {
                let httpClient = HTTPClient()
                defer {
                    // it's important to shutdown the httpClient after all requests are done, even if one failed. See: https://github.com/swift-server/async-http-client
                    try? httpClient.syncShutdown()
                }

                let llm = ChatOpenAI( httpClient: httpClient, model: Model.GPT3.gpt3_5Turbo_0125, callbacks: [ Callback() ])
                
//                let agent = initialize_agent(llm: llm, tools: [Dummy(), JavascriptREPLTool(), TTSTool()], callbacks: [ Callback() ])
//                
//                print( await agent.run(args: input) )
                
                try await runAgent(input: input,
                                   llm: llm,
                                   tools: [Dummy(), JavascriptREPLTool(), TTSTool()],
                                   callbacks: [ Callback() ])
            }
            catch {
                await setProgress("ERROR: \(error)")
            }
        }
        
    }
    
}

#Preview {
    ContentView()
}

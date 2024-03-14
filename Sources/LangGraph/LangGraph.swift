import OSLog

public typealias PartialAgentState = [String: Any]

public typealias NodeAction<Action: AgentState> = ( Action ) async throws -> PartialAgentState
public typealias EdgeCondition<Action: AgentState> = ( Action ) async throws -> String

public protocol AgentState {
    
    var data: [String: Any] { get }
    
//    subscript(key: String) -> Any? { get }
    
    init()
    init( _ initState: [String: Any] )
    
}

public struct BaseAgentState : AgentState {
    
    subscript(key: String) -> Any? {
        data[key]
    }
    
    public var data: [String : Any]
    
    public init() {
        data = [:]
    }
    
    public init(_ initState: [String : Any]) {
        data = initState
    }
    
    
}
public enum GraphStateError : Error {
    case duplicateNodeError( String )
    case duplicateEdgeError( String )
    case missingEntryPoint
    case entryPointNotExist( String )
    case finishPointNotExist( String )
    case missingNodeInEdgeMapping( String )
    case edgeMappingIsEmpty
    case invalidEdgeIdentifier( String )
    case invalidNodeIdentifier( String )
    case missingNodeReferencedByEdge( String )
    
    public var localizedDescription: String {
        switch(self) {
        case .duplicateNodeError(let message):
            message
        case .duplicateEdgeError(let message):
            message
        case .missingEntryPoint:
            "missing entry point!"
        case .entryPointNotExist(let message):
            message
        case .finishPointNotExist(let message):
            message
        case .missingNodeInEdgeMapping(let message):
            message
        case .edgeMappingIsEmpty:
            "edge mapping is empty!"
        case .invalidNodeIdentifier(let message):
            message
        case .missingNodeReferencedByEdge(let message):
            message
        case .invalidEdgeIdentifier(let message):
            message
        }
    }

}

public enum GraphRunnerError : Error {
    case missingEdge( String )
    case missingNode( String )
    case missingNodeInEdgeMapping( String )
    case executionError( String )
    
    public var localizedDescription: String {
        switch(self) {
        case .missingEdge(let message):
            message
        case .missingNode(let message):
            message
        case .missingNodeInEdgeMapping(let message):
            message
        case .executionError(let message):
            message
        }
    }
}

public let END = "__END__" // id of the edge ending workflow

//enum Either<Left, Right> {
//    case left(Left)
//    case right(Right)
//}

let log = Logger( subsystem: Bundle.module.bundleIdentifier ?? "langgraph", category: "main")

public class GraphState<State: AgentState>  {
    
    enum EdgeValue /* Either */ {
        case id(String)
        case condition( ( EdgeCondition<State>, [String:String] ) )
    }
    
    public class Runner {
        
        
        var stateType: State.Type
        var nodes:Dictionary<String, NodeAction<State>>
        var edges:Dictionary<String, EdgeValue>
        var entryPoint:String
        var finishPoint:String?

        init( owner: GraphState ) {
            
            self.stateType = owner.stateType
            self.nodes = Dictionary()
            self.edges = Dictionary()
            self.entryPoint = owner.entryPoint!
            self.finishPoint = owner.finishPoint
            
            owner.nodes.forEach { [unowned self] node in
                nodes[node.id] = node.action
            }
            
            owner.edges.forEach { [unowned self] edge in
                edges[edge.sourceId] = edge.target
            }
        }
        
        private func mergeState( currentState: State, partialState: PartialAgentState ) -> State {
            if partialState.isEmpty {
                return currentState
            }
            let newState = currentState.data.merging(partialState, uniquingKeysWith: { (current, _) in
                return current
            })
            return State.init(newState)
        }
        
        
        private func nextNodeId( nodeId: String, agentState: State ) async throws -> String {
            
            guard let route = edges[nodeId] else {
                throw GraphRunnerError.missingEdge("edge with node: \(nodeId) not found!")
            }
            
            switch( route ) {
            case .id( let nextNodeId ):
                return nextNodeId
            case .condition( let (condition, mapping)):
                
                let newRoute = try await condition( agentState )
                guard let result = mapping[newRoute] else {
                    throw GraphRunnerError.missingNodeInEdgeMapping("cannot find edge mapping for id: \(newRoute) in conditional edge with sourceId:\(nodeId) ")
                }
                return result
            }
        }
        
        public func invoke( inputs: PartialAgentState, verbose:Bool = false ) async throws -> State {
            
            var currentState = self.stateType.init( inputs )
            var currentNodeId = entryPoint
            
            repeat {
                
                guard let action = nodes[currentNodeId] else {
                    throw GraphRunnerError.missingNode("node: \(currentNodeId) not found!")
                }

                if( verbose ) {
                    log.debug("start processing node \(currentNodeId)")
                }
                let partialState = try await action( currentState )
                
                currentState = mergeState( currentState: currentState, partialState: partialState)
                
                if( currentNodeId == finishPoint ) {
                    break
                }

                currentNodeId = try await nextNodeId(nodeId: currentNodeId, agentState: currentState)

            } while( currentNodeId != END )
            
            return currentState
        }

    }

    struct Edge : Hashable, Identifiable{
        var id: String {
            sourceId
        }
        static func == (lhs: GraphState.Edge, rhs: GraphState.Edge) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            id.hash(into: &hasher)
        }
        
        var sourceId:String
        var target:EdgeValue
        
    }

    private var edges: Set<Edge> = []
    
    struct Node : Hashable, Identifiable {
        static func == (lhs: GraphState.Node, rhs: GraphState.Node) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            id.hash(into: &hasher)
        }
        
        var id: String
        var action: NodeAction<State>
    }
    
    private var nodes: Set<Node> = []

    private var entryPoint: String?
    private var finishPoint: String?

    private var stateType: State.Type
    
    public init( stateType: State.Type ) {
        self.stateType = stateType
        
    }
    
    public func addNode( _ id: String, action: @escaping NodeAction<State> ) throws {
        guard id != END else {
            throw GraphStateError.invalidNodeIdentifier( "END is not a valid node id!")
        }
        let node = Node(id: id,action: action)
        if nodes.contains(node) {
            throw GraphStateError.duplicateNodeError("node with id:\(id) already exist!")
        }
        nodes.insert( node )
        
    }
    public func addEdge( sourceId: String, targetId: String ) throws {
        guard sourceId != END else {
            throw GraphStateError.invalidEdgeIdentifier( "END is not a valid edge sourceId!")
        }

        let edge = Edge(sourceId: sourceId, target: .id(targetId) )
        if edges.contains(edge) {
            throw GraphStateError.duplicateEdgeError("edge with id:\(sourceId) already exist!")
        }
        edges.insert( edge )
    }
    public func addConditionalEdge( sourceId: String, condition: @escaping EdgeCondition<State>, edgeMapping: [String:String] ) throws {
        guard sourceId != END else {
            throw GraphStateError.invalidEdgeIdentifier( "END is not a valid edge sourceId!")
        }
        if edgeMapping.isEmpty {
            throw GraphStateError.edgeMappingIsEmpty
        }

        let edge = Edge(sourceId: sourceId, target: .condition(( condition, edgeMapping)) )
        if edges.contains(edge) {
            throw GraphStateError.duplicateEdgeError("edge with id:\(sourceId) already exist!")
        }
        edges.insert( edge)
    }
    public func setEntryPoint( _ nodeId: String ) throws {
        guard nodeId != END else {
            throw GraphStateError.invalidNodeIdentifier( "END is not a valid node entry point!")
        }
        entryPoint = nodeId
    }
    public func setFinishPoint( _ nodeId: String ) {
        finishPoint = nodeId
    }
    
    private var fakeAction:NodeAction<State> = { _ in  return [:] }

    private func makeFakeNode( _ id: String ) -> Node {
        Node(id: id, action: fakeAction)
    }
    
    public func compile() throws -> Runner {
        guard let entryPoint else {
            throw GraphStateError.missingEntryPoint
        }
        
        guard nodes.contains( makeFakeNode( entryPoint ) ) else {
            throw GraphStateError.entryPointNotExist( "entryPoint: \(entryPoint) doesn't exist!")
        }
        
        if let finishPoint {
            guard nodes.contains( makeFakeNode( finishPoint ) ) else {
                throw GraphStateError.finishPointNotExist( "finishPoint: \(finishPoint) doesn't exist!")
            }
        }
        // TODO check edges
        for edge in edges {
            
            guard nodes.contains( makeFakeNode(edge.sourceId) ) else {
                throw GraphStateError.missingNodeReferencedByEdge( "edge sourceId: \(edge.sourceId) reference a not existent node!")
            }

            switch( edge.target ) {
            case .id( let targetId ):
                guard targetId==END || nodes.contains(makeFakeNode(targetId) ) else {
                    throw GraphStateError.missingNodeReferencedByEdge( "edge sourceId: \(edge.sourceId)  reference a not existent targetId: \(targetId) node!")
                }
                break
            case .condition((_, let edgeMappings)):
                for (_,nodeId) in edgeMappings {
                    guard nodeId==END || nodes.contains(makeFakeNode(nodeId) ) else {
                        throw GraphStateError.missingNodeInEdgeMapping( "edge mapping for sourceId: \(edge.sourceId) contains a not existen nodeId \(nodeId)!")
                    }
                }
            }
        }
        
        return Runner( owner: self )
    }
}

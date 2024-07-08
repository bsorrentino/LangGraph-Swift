import OSLog

public typealias PartialAgentState = [String: Any]

public typealias NodeAction<Action: AgentState> = ( Action ) async throws -> PartialAgentState
public typealias EdgeCondition<Action: AgentState> = ( Action ) async throws -> String

protocol AppendableValueProtocol {
    associatedtype ItemType
    
    var array: [ItemType] { get set }
    
    mutating func append( values: [Any] ) throws
    mutating func append( value: Any ) throws

}

public struct AppendableValue<T> : AppendableValueProtocol {
    typealias ItemType = T
    
    var array: [T]
    
    mutating func append( value: T ) {
        array.append(value)
    }
    
    mutating func append( values: [Any] ) throws {
        guard let typedValues = values as? [T] else {
            throw CompiledGraphError.executionError( "AppenderValue type mismatch!")
        }
        array.append(contentsOf: typedValues)
    }
    mutating func append( value: Any ) throws {
        guard let typedValue = value as? T else {
            throw CompiledGraphError.executionError( "AppenderValue type mismatch!")
        }
        array.append(typedValue)
    }

    public init() {
        array = []
    }

    public init( values: [T] ) {
        array = values
    }
    
}

public protocol AgentState {
    
    var data: [String: Any] { get }
    
//    subscript(key: String) -> Any? { get }
    
    init( _ initState: [String: Any] )
}

extension AgentState {

    public func value<T>( _ key: String ) -> T? {
        return data[ key ] as? T
    }
                
    public func appendableValue<T>( _ key: String ) -> [T]? {
        return (data[ key ] as? AppendableValue<T>)?.array as? [T]
    }
}

public struct NodeOutput<State: AgentState> {
    public var node: String
    public var state: State
    
    public init(node: String, state: State) {
        self.node = node
        self.state = state
    }
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
public enum StateGraphError : Error {
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

public enum CompiledGraphError : Error {
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

public class StateGraph<State: AgentState>  {
    
    enum EdgeValue /* Union */ {
        case id(String)
        case condition( ( EdgeCondition<State>, [String:String] ) )
    }
    
    public class CompiledGraph {
    
        var stateFactory: () -> State
        var nodes:Dictionary<String, NodeAction<State>>
        var edges:Dictionary<String, EdgeValue>
        var entryPoint:String
        var finishPoint:String?

        init( owner: StateGraph ) {
            
            self.stateFactory = owner.stateFactory
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
        
        private func mergeState( currentState: State, partialState: PartialAgentState ) throws -> State {
            if partialState.isEmpty {
                return currentState
            }
            let newState = try currentState.data.merging(partialState, uniquingKeysWith: {
                (current, new) in
                
                if var appender = current as? (any AppendableValueProtocol) {
                    if let newValue = new as? [Any] {
                        try appender.append(values: newValue )
                    }
                    else {
                        try appender.append(value: new)
                    }
                    return appender
                }
                return new
            })
            return State.init(newState)
        }
        
        
        private func nextNodeId( nodeId: String, agentState: State ) async throws -> String {
            
            guard let route = edges[nodeId] else {
                throw CompiledGraphError.missingEdge("edge with node: \(nodeId) not found!")
            }
            
            switch( route ) {
            case .id( let nextNodeId ):
                return nextNodeId
            case .condition( let (condition, mapping)):
                
                let newRoute = try await condition( agentState )
                guard let result = mapping[newRoute] else {
                    throw CompiledGraphError.missingNodeInEdgeMapping("cannot find edge mapping for id: \(newRoute) in conditional edge with sourceId:\(nodeId) ")
                }
                return result
            }
        }
        
        public func stream( inputs: PartialAgentState, verbose:Bool = false ) -> AsyncThrowingStream<NodeOutput<State>, Error> {
            
            let (stream, continuation) = AsyncThrowingStream.makeStream(of: NodeOutput<State>.self, throwing: Error.self)
            
            Task {
                
                do {
                    var currentNodeId = entryPoint
                    var currentState = try mergeState( currentState: self.stateFactory(), partialState: inputs)

                    repeat {
                        
                        guard let action = nodes[currentNodeId] else {
                            continuation.finish(throwing: CompiledGraphError.missingNode("node: \(currentNodeId) not found!") )
                            break
                        }
                        
                        if( verbose ) {
                            log.debug("start processing node \(currentNodeId)")
                        }
                        
                        try Task.checkCancellation()
                        let partialState = try await action( currentState )
                        
                        currentState = try mergeState( currentState: currentState, partialState: partialState)
                        
                        let output = NodeOutput(node: currentNodeId,state: currentState)
                        
                        try Task.checkCancellation()
                        continuation.yield( output )

                        if( currentNodeId == finishPoint ) {
                            break
                        }
                        
                        currentNodeId = try await nextNodeId(nodeId: currentNodeId, agentState: currentState)
                        
                    } while( currentNodeId != END && !Task.isCancelled )
                    
                    continuation.finish()
                }
                catch {
                    continuation.finish(throwing: error)
                }
            }
            
            return stream
        }
        
        
        /// run the graph an return the final State
        ///
        /// - Parameters:
        ///   - inputs: partial state
        ///   - verbose: enable verbose output (log)
        /// - Returns: final State
        public func invoke( inputs: PartialAgentState, verbose:Bool = false ) async throws -> State {
            
            let initResult:[NodeOutput<State>] = []
            let result = try await stream(inputs: inputs).reduce( initResult, { partialResult, output in
                [output]
            })
            if result.isEmpty {
                throw CompiledGraphError.executionError("no state has been produced! probably processing has been interrupted")
            }
            return result[0].state
        }
    }

    struct Edge : Hashable, Identifiable{
        var id: String {
            sourceId
        }
        static func == (lhs: StateGraph.Edge, rhs: StateGraph.Edge) -> Bool {
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
        static func == (lhs: StateGraph.Node, rhs: StateGraph.Node) -> Bool {
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

    private var stateFactory: () -> State
    
    public init( stateFactory: @escaping () -> State ) {
        self.stateFactory = stateFactory
        
    }
    
    public func addNode( _ id: String, action: @escaping NodeAction<State> ) throws {
        guard id != END else {
            throw StateGraphError.invalidNodeIdentifier( "END is not a valid node id!")
        }
        let node = Node(id: id,action: action)
        if nodes.contains(node) {
            throw StateGraphError.duplicateNodeError("node with id:\(id) already exist!")
        }
        nodes.insert( node )
        
    }
    public func addEdge( sourceId: String, targetId: String ) throws {
        guard sourceId != END else {
            throw StateGraphError.invalidEdgeIdentifier( "END is not a valid edge sourceId!")
        }

        let edge = Edge(sourceId: sourceId, target: .id(targetId) )
        if edges.contains(edge) {
            throw StateGraphError.duplicateEdgeError("edge with id:\(sourceId) already exist!")
        }
        edges.insert( edge )
    }
    public func addConditionalEdge( sourceId: String, condition: @escaping EdgeCondition<State>, edgeMapping: [String:String] ) throws {
        guard sourceId != END else {
            throw StateGraphError.invalidEdgeIdentifier( "END is not a valid edge sourceId!")
        }
        if edgeMapping.isEmpty {
            throw StateGraphError.edgeMappingIsEmpty
        }

        let edge = Edge(sourceId: sourceId, target: .condition(( condition, edgeMapping)) )
        if edges.contains(edge) {
            throw StateGraphError.duplicateEdgeError("edge with id:\(sourceId) already exist!")
        }
        edges.insert( edge)
    }
    public func setEntryPoint( _ nodeId: String ) throws {
        guard nodeId != END else {
            throw StateGraphError.invalidNodeIdentifier( "END is not a valid node entry point!")
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
    
    public func compile() throws -> CompiledGraph {
        guard let entryPoint else {
            throw StateGraphError.missingEntryPoint
        }
        
        guard nodes.contains( makeFakeNode( entryPoint ) ) else {
            throw StateGraphError.entryPointNotExist( "entryPoint: \(entryPoint) doesn't exist!")
        }
        
        if let finishPoint {
            guard nodes.contains( makeFakeNode( finishPoint ) ) else {
                throw StateGraphError.finishPointNotExist( "finishPoint: \(finishPoint) doesn't exist!")
            }
        }
        // TODO check edges
        for edge in edges {
            
            guard nodes.contains( makeFakeNode(edge.sourceId) ) else {
                throw StateGraphError.missingNodeReferencedByEdge( "edge sourceId: \(edge.sourceId) reference to non existent node!")
            }

            switch( edge.target ) {
            case .id( let targetId ):
                guard targetId==END || nodes.contains(makeFakeNode(targetId) ) else {
                    throw StateGraphError.missingNodeReferencedByEdge( "edge sourceId: \(edge.sourceId)  reference to non existent node targetId: \(targetId) node!")
                }
                break
            case .condition((_, let edgeMappings)):
                for (_,nodeId) in edgeMappings {
                    guard nodeId==END || nodes.contains(makeFakeNode(nodeId) ) else {
                        throw StateGraphError.missingNodeInEdgeMapping( "edge mapping for sourceId: \(edge.sourceId) contains a not existent nodeId \(nodeId)!")
                    }
                }
            }
        }
        
        return CompiledGraph( owner: self )
    }
}

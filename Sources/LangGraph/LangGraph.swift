import OSLog

/**
 A typealias representing a partial state of an agent.
 */
public typealias PartialAgentState = [String: Any]

/**
 A typealias representing an action to be performed on an agent state.
 
 - Parameters:
    - Action: The type of the agent state.
 - Returns: A partial state of the agent.
 */
public typealias NodeAction<Action: AgentState> = (Action) async throws -> PartialAgentState

/**
 A typealias representing a condition to be checked on an agent state.
 
 - Parameters:
    - Action: The type of the agent state.
 - Returns: A string representing the result of the condition check.
 */
public typealias EdgeCondition<Action: AgentState> = (Action) async throws -> String

/**
 A typealias representing a reducer function.
 
 - Parameters:
    - Value: The type of the value to be reduced.
 - Returns: A reduced value.
 */
public typealias Reducer<Value> = (Value?, Value) -> Value

/**
 A typealias representing a default value provider.
 
 - Returns: A default value.
 */
public typealias DefaultProvider<Value> = () throws -> Value

/**
 A typealias representing a factory for creating agent states.
 
 - Parameters:
    - State: The type of the agent state.
 - Returns: A new agent state.
 */
public typealias StateFactory<State: AgentState> = ([String: Any]) -> State

/// Update Struct
//func updated <T> (_ value: T, with update: (inout T) -> Void) -> T {
//    var editable = value
//    update(&editable)
//    return editable
//}

// A type-erasing wrapper for any Encodable value
struct AnyEncodable: Encodable {
    let value: Encodable

    func encode(to encoder: Encoder) throws {
        // Here, we directly encode the underlying value
        // The encoder will figure out the concrete type at runtime
        try value.encode(to: encoder)
    }
}

struct AnyDecodable: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyDecodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyDecodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type found.")
        }
    }
}

func toEncodableStateData( data: [String: Any], skippingNonEncodable: Bool = true) throws -> [String: AnyEncodable] {
    return try data.compactMapValues { value -> AnyEncodable? in
        
        switch value {
        case let dict as [String: Any]:
            // Recursively handle dictionaries
            return AnyEncodable(value: dict.compactMapValues { $0 as? Encodable }.mapValues { AnyEncodable(value: $0) })
        case let array as [Any]:
            // Recursively handle arrays
            return AnyEncodable(value: array.compactMap { $0 as? Encodable }.map { AnyEncodable(value: $0) })
        default:
            // Check if the value is Encodable
            guard let encodableValue = value as? Encodable else {
                if( !skippingNonEncodable ) {
                    throw EncodingError.invalidValue(value,
                                                     EncodingError.Context(codingPath: [],
                                                                           debugDescription: "Value \(value) cannot be encoded."))
                }
                return nil
            }
            return AnyEncodable(value: encodableValue)
        }
    }
}
    
func encodeStateData(encoder: JSONEncoder, state: [String: Any], skippingNonEncodable: Bool = true) throws -> Data {
    
    let encodableState =  try toEncodableStateData(data: state, skippingNonEncodable: skippingNonEncodable)
    
    return try encoder.encode(encodableState)

}

func decodeStateData( decoder: JSONDecoder, from data: Data ) throws -> [String: Any] {
    let decodedDictionary = try decoder.decode([String: AnyDecodable].self, from: data)
    return decodedDictionary.mapValues { $0.value }
}

/**
 A protocol defining the requirements for a channel.
 */
public protocol ChannelProtocol {
    associatedtype T
    
    /// A reducer function for the channel.
    var reducer: Reducer<T>? { get }
    
    /// A default value provider for the channel.
    var `default`: DefaultProvider<T>? { get }

    /**
     Updates the channel with a new value.
     
     - Parameters:
        - name: The name of attribute that will be updated.
        - oldValue: The old value of the channel.
        - newValue: The new value to update the channel with.
     - Throws: An error if the update fails.
     - Returns: The updated value.
     */
    func updateAttribute(_ name: String, oldValue: Any?, newValue: Any) throws -> Any
}
/**
 A class representing a communication channel that conforms to `ChannelProtocol`.

 `Channel` is a generic class that provides mechanisms to update and manage values
 of a specific type. It supports optional reducer functions and default value providers
 to handle value updates and initializations.

 - Parameters:
    - T: The type of the value managed by the channel.
 */
public class Channel<T> : ChannelProtocol {
    /// A reducer function for the channel.
    public var reducer: Reducer<T>?
    
    /// A default value provider for the channel.
    public var `default`: DefaultProvider<T>?
    
    /**
     Initializes a new instance of `Channel`.
     
     - Parameters:
        - reducer: An optional reducer function to handle value updates.
        - defaultValueProvider: An optional default value provider to initialize the channel's value.
     */
    public init(reducer: Reducer<T>? = nil, default defaultValueProvider: DefaultProvider<T>? = nil ) {
        self.reducer = reducer
        self.`default` = defaultValueProvider
    }
    
    private func decodeOptionalAttributeValue( _ value: Any?, withName name: String, andValueDescription description: String ) throws -> T?
    {
        guard let value else { return nil }
        
        return try decodeAttributeValue(value, withName: name, andValueDescription: description)
    }
    
    private func decodeAttributeValue( _ value: Any, withName name: String, andValueDescription description: String ) throws -> T {
        if let _value = value as? T {
            return _value
        }
        
        guard let decodableType = T.self as? Decodable.Type else {
            throw CompiledGraphError.executionError(
                "Channel: Type mismatch updating '\(description)' for property \(name)!")
        }
        
        // Try to deserialize from JSON if T conforms to Decodable
        let decoded: Decodable
        do {
            // Convert to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: value)
            
            // Decode to the expected type
            decoded = try JSONDecoder().decode(decodableType, from: jsonData)
        } catch {
            throw CompiledGraphError.executionError(
                "Channel: Type mismatch updating '\(description)' for property \(name)!")
        }
        
        guard let typedDecoded = decoded as? T else {
            throw CompiledGraphError.executionError(
                "Channel: Type mismatch updating '\(description)' for property \(name) after JSON decoding!")
        }

        return typedDecoded

    }

    /**
     Updates the channel with a new value.
     
     This method updates the channel's value by applying the reducer function if provided,
     or directly setting the new value if no reducer is available. It also handles type
     mismatches and provides default values when necessary.
     
     - Parameters:
        - name: The name of attribute that will be updated.
        - oldValue: The old value of the channel, which can be `nil`.
        - newValue: The new value to update the channel with.
     - Throws: An error if the update fails due to type mismatches.
     - Returns: The updated value.
     */
    public func updateAttribute( _ name: String, oldValue: Any?, newValue: Any ) throws -> Any {
        let new = try self.decodeAttributeValue(newValue, withName: name, andValueDescription: "newValue")
        let old = try self.decodeOptionalAttributeValue(oldValue, withName: name, andValueDescription: "oldValue")
        
        if let reducer {
            return reducer( old, new )
        }
        return new
    }
}


/**
 A specialized `Channel` that appends new values to an array of existing values.
 
 `AppenderChannel` is a subclass of `Channel` designed to handle arrays of values.
 It provides functionality to append new values to the existing array, using a reducer function.
 
 - Note: The default value provider initializes the channel with an empty array if not specified.
 
 - Parameters:
    - T: The type of elements in the array managed by this channel.
 */
public class AppenderChannel<T> : Channel<[T]> {
    
    /**
     Initializes a new instance of `AppenderChannel`.
     
     - Parameter defaultValueProvider: A closure that provides the default value for the channel.
       If not provided, the default value is an empty array.
     */
    public init(default defaultValueProvider: @escaping DefaultProvider<[T]> = { [] }) {
        super.init()
        self.reducer = { left, right in
            guard var left else {
                return right
            }
            left.append(contentsOf: right)
            return left
        }
        self.default = defaultValueProvider
    }
    
    /**
     Updates the channel with a new value.
     
     This method updates the channel's value by appending the new value to the existing array.
     If the new value is a single element, it is converted to an array before appending.
     
     - Parameters:
        - name: The name of attribute that will be updated.
        - oldValue: The old value of the channel, which can be `nil`.
        - newValue: The new value to update the channel with.
     - Throws: An error if the update fails due to type mismatches.
     - Returns: The updated value.
     */
    public override func updateAttribute( _ name: String, oldValue: Any?, newValue: Any) throws -> Any {
        if let new = newValue as? T {
            print("Updating \(name), as type \(T.self)")
            return try super.updateAttribute( name, oldValue: oldValue, newValue: [new])
        }
        print("Updating \(name), but without type T")
        return try super.updateAttribute( name, oldValue: oldValue, newValue: newValue)
    }
}

/**
 A typealias representing channels' map in the form [<attribute name>:<related channel>].
 */
public typealias Channels = [String: any ChannelProtocol ]

/// A protocol representing the state of an agent.
///
/// The `AgentState` protocol defines the requirements for any type that represents
/// the state of an agent. It includes a dictionary to store state data and an initializer
/// to set up the initial state.
public protocol AgentState {
    
    /// A dictionary to store the state data.
    var data: [String: Any] { get }
    
    /// Initializes a new instance of an agent state with the given initial state.
    ///
    /// - Parameter initState: A dictionary representing the initial state.
    init(_ initState: [String: Any])
}

/**
 AgentState extension to define accessor methods
 */
extension AgentState {

    /// Retrieves the value associated with the specified key.
    ///
    /// - Parameter key: The key for which to return the corresponding value.
    /// - Returns: The value associated with `key` as type `T`, or `nil` if the key does not exist or the value cannot be cast to type `T`.
    public func value<T>(_ key: String) -> T? {
        guard let value = data[key] else {
            return nil
        }
        
        // First try direct casting
        if let directValue = value as? T {
            print("Value \(key) successfully cast to \(T.self)")
            return directValue
        }
        
        // Try to deserialize from JSON if T conforms to Decodable
        print("Value \(key) could not be cast to \(T.self), trying JSON decoding")
        if let decodableType = T.self as? Decodable.Type {
            do {
                // Convert to JSON data
                let jsonData = try JSONSerialization.data(withJSONObject: value)
                
                // Decode to the expected type
                let decoded = try JSONDecoder().decode(decodableType, from: jsonData)
                if let typedDecoded = decoded as? T {
                    print("Value \(key) successfully JSON decoded to \(T.self)")
                    return typedDecoded
                } else {
                    print("Value: type is \(value.self)")
                    print("DEBUG: Type T is \(T.self) for key \(key)")
                    print("JSON decoding failed - could not cast decoded value to \(T.self)")
                }
            } catch {
                print("JSON deserialization failed for key \(key): \(error)")
                print("Value: type is \(value.self)")
                print("DEBUG: Type T is \(T.self) for key \(key)")
            }
        } else {
            print("Value: type is \(value.self)")
            print("DEBUG: Type T is \(T.self) for key \(key)")
            print("Type \(T.self) does not conform to Decodable")
        }
        
        return nil
    }
    
}

func updateState( currentState: [String: Any], partialState: [String: Any], channels: Channels ) throws -> [String: Any] {
    let mappedValues = try partialState.map { key, value in
        if let channel = channels[key] {
            do {
                let newValue = try channel.updateAttribute( key, oldValue: currentState[key], newValue: value)
                return (key, newValue)
            } catch CompiledGraphError.executionError(let message) {
                throw CompiledGraphError.executionError("error processing property: '\(key)' - \(message)")
            }
        }
        return (key, value)
    }
    
    return currentState.merging( Dictionary( uniqueKeysWithValues: mappedValues), uniquingKeysWith: {
        (current, new ) in  new
    })
}


extension AgentState {
    
    @inline(__always)
    func updateStateData( partialState: [String: Any], channels: Channels ) throws -> [String: Any] {
        return try LangGraph.updateState( currentState: data, partialState: partialState, channels: channels )
    }

}

extension Dictionary where Key == String, Value == Any {
    
    func clone() throws -> Self {
        let data = try encodeStateData(encoder: JSONEncoder(), state: self )
        
        return try decodeStateData(decoder: JSONDecoder(), from: data)
    }
    

}

extension AgentState {
    
    @inline(__always)
    func clone() throws -> Self {
        return .init( try data.clone() )
    }

}

/// A structure representing the output of a node in a state graph.
///
/// `NodeOutput` encapsulates the node identifier and its associated state.
///
/// - Parameters:
///   - State: The type conforming to `AgentState` representing the state of the node.
public struct NodeOutput<State: AgentState> {
    
    /// The identifier of the node.
    public var node: String
    
    /// The state associated with the node.
    public var state: State
    
    /// Initializes a new `NodeOutput` instance with the specified node identifier and state.
    ///
    /// - Parameters:
    ///   - node: A `String` representing the identifier of the node.
    ///   - state: An instance of `State` representing the state associated with the node.
    public init(node: String, state: State) {
        self.node = node
        self.state = state
    }
}

public enum GraphInput {
    case args([String: Any])
    case resume
}

/// A structure representing the base state of an agent.
///
/// `BaseAgentState` conforms to the `AgentState` protocol and provides mechanisms
/// to initialize and access the state data.
///
/// - Tag: BaseAgentState
public struct BaseAgentState: AgentState {
    
    /// Accesses the value associated with the given key.
    ///
    /// - Parameter key: The key to find in the state data.
    /// - Returns: The value associated with `key`, or `nil` if the key does not exist.
    public subscript(key: String) -> Any? {
        value(key)
    }
    
    /// A dictionary to store the state data.
    public var data: [String: Any]
    
    /// Initializes a new instance of `BaseAgentState` with an empty state.
    public init() {
        data = [:]
    }
    
    /// Initializes a new instance of `BaseAgentState` with the given initial state.
    ///
    /// - Parameter initState: A dictionary representing the initial state.
    public init(_ initState: [String: Any]) {
        data = initState
    }
    
}

/// A configuration structure used during the compilation of a `StateGraph`.
///
/// `CompileConfig` allows specifying optional behaviors like saving checkpoints and defining
/// interruptions that should pause graph execution before specific nodes.
public struct CompileConfig {
    /// An optional saver to persist state checkpoints.
    public let checkpointSaver: CheckpointSaver?

    /// Node identifiers where execution should pause before processing.
    public let interruptionsBefore: [String]

    /// Creates a new `CompileConfig`.
    ///
    /// - Parameters:
    ///   - checkpointSaver: A `CheckpointSaver` used to persist checkpoints. Defaults to `nil`.
    ///   - interruptionsBefore: An array of node identifiers to pause before. Defaults to `[]`.
    public init(checkpointSaver: CheckpointSaver? = nil, interruptionsBefore: [String] = []  ) {
        self.checkpointSaver = checkpointSaver
        self.interruptionsBefore = interruptionsBefore
    }
}

/// A configuration structure used to control the execution of a compiled graph.
///
/// `RunnableConfig` provides metadata such as thread and checkpoint identifiers to manage execution context,
/// as well as a verbosity flag for debugging purposes.
public struct RunnableConfig {
    /// An optional identifier to track execution thread.
    public var threadId: String?

    /// An optional UUID of the last saved checkpoint.
    public var checkpointId: UUID?

    /// An optional identifier of the next node to execute.
    public var nextNodeId: String?

    /// A flag indicating whether verbose logging is enabled.
    public var verbose: Bool

    /// Creates a new `RunnableConfig`.
    ///
    /// - Parameters:
    ///   - threadId: The thread identifier for the execution context.
    ///   - checkpointId: The last checkpoint identifier.
    ///   - verbose: Whether verbose logging is enabled.
    public init(threadId: String? = nil, checkpointId: UUID? = nil, verbose: Bool = false) {
        self.threadId = threadId
        self.verbose = verbose
        self.checkpointId = checkpointId
    }
}

extension RunnableConfig {

    public func with( update: (inout Self) -> Void) -> Self {
        var editable = self
        update(&editable)
        return editable
    }

}

/**
 An enumeration representing various errors that can occur in a `StateGraph`.

 `StateGraphError` conforms to the `Error` and `LocalizedError` protocols to provide
 detailed error descriptions for different failure scenarios in a state graph.

 - Tag: StateGraphError
 */
public enum StateGraphError: Error, LocalizedError {
    /// An error indicating a duplicate node identifier.
    ///
    /// - Parameter message: A `String` describing the duplicate node error.
    case duplicateNodeError(String)
    
    /// An error indicating a duplicate edge identifier.
    ///
    /// - Parameter message: A `String` describing the duplicate edge error.
    case duplicateEdgeError(String)
    
    /// An error indicating a missing entry point in the state graph.
    case missingEntryPoint
    
    /// An error indicating that the specified entry point does not exist.
    ///
    /// - Parameter message: A `String` describing the missing entry point error.
    case entryPointNotExist(String)
    
    /// An error indicating that the specified finish point does not exist.
    ///
    /// - Parameter message: A `String` describing the missing finish point error.
    case finishPointNotExist(String)
    
    /// An error indicating a missing node in the edge mapping.
    ///
    /// - Parameter message: A `String` describing the missing node in edge mapping error.
    case missingNodeInEdgeMapping(String)
    
    /// An error indicating that the edge mapping is empty.
    case edgeMappingIsEmpty
    
    /// An error indicating an invalid edge identifier.
    ///
    /// - Parameter message: A `String` describing the invalid edge identifier error.
    case invalidEdgeIdentifier(String)
    
    /// An error indicating an invalid node identifier.
    ///
    /// - Parameter message: A `String` describing the invalid node identifier error.
    case invalidNodeIdentifier(String)
    
    /// An error indicating a missing node referenced by an edge.
    ///
    /// - Parameter message: A `String` describing the missing node referenced by edge error.
    case missingNodeReferencedByEdge(String)
    
    /// A localized description of the error.
    public var errorDescription: String? {
        switch self {
        case .duplicateNodeError(let message):
            return message
        case .duplicateEdgeError(let message):
            return message
        case .missingEntryPoint:
            return "Missing entry point!"
        case .entryPointNotExist(let message):
            return message
        case .finishPointNotExist(let message):
            return message
        case .missingNodeInEdgeMapping(let message):
            return message
        case .edgeMappingIsEmpty:
            return "Edge mapping is empty!"
        case .invalidNodeIdentifier(let message):
            return message
        case .missingNodeReferencedByEdge(let message):
            return message
        case .invalidEdgeIdentifier(let message):
            return message
        }
    }
}

/**
 An enumeration representing errors that can occur in a compiled graph.

 The `CompiledGraphError` enumeration defines various error cases that can be encountered
 during the execution and manipulation of a compiled graph. Each case is associated with
 a descriptive message to provide more context about the error.

 - Conforms To: `Error`, `LocalizedError`
 */
public enum CompiledGraphError: Error, LocalizedError {
    /**
     An error indicating that an edge is missing in the graph.
     
     - Parameter message: A `String` describing the missing edge error.
     */
    case missingEdge(String)
    
    /**
     An error indicating that a node is missing in the graph.
     
     - Parameter message: A `String` describing the missing node error.
     */
    case missingNode(String)
    
    /**
     An error indicating a missing node in the edge mapping.
     
     - Parameter message: A `String` describing the missing node in edge mapping error.
     */
    case missingNodeInEdgeMapping(String)
    
    /**
     An error indicating an execution error in the graph.
     
     - Parameter message: A `String` describing the execution error.
     */
    case executionError(String)
    
    /**
     A localized description of the error.
     
     This property provides a human-readable description of the error, which can be used
     for displaying error messages to the user.
     
     - Returns: A `String` describing the error.
     */
    public var errorDescription: String? {
        switch self {
        case .missingEdge(let message):
            return message
        case .missingNode(let message):
            return message
        case .missingNodeInEdgeMapping(let message):
            return message
        case .executionError(let message):
            return message
        }
    }
}

/// Identifier of the edge staring workflow ( = `"__START__"` )
public let START = "__START__"
/// Identifier of the edge ending workflow ( = `"__END__"` )
public let END = "__END__"

//enum Either<Left, Right> {
//    case left(Left)
//    case right(Right)
//}

/// private log for module
let log = Logger( subsystem: Bundle.module.bundleIdentifier ?? "langgraph", category: "main")

/// A class representing a state graph.
///
/// `StateGraph` is a generic class that manages the state transitions and actions within a state graph.
/// It allows adding nodes and edges, including conditional edges, and provides functionality to compile
/// the graph into a `CompiledGraph`.
///
/// - Parameters:
///    - State: The type of the agent state managed by the graph.
public class StateGraph<State: AgentState>  {
    
    /// An enumeration representing the value of an edge.
    ///
    /// `EdgeValue` can either be an identifier or a condition with edge mappings.
    enum EdgeValue {
        /// Represents an edge with a target identifier.
        case id(String)
        
        /// Represents an edge with a condition and edge mappings.
        case condition( ( EdgeCondition<State>, [String:String] ) )
    }
    
    /// A structure representing an edge in the state graph.
    ///
    /// `Edge` conforms to `Hashable` and `Identifiable` protocols.
    struct Edge : Hashable, Identifiable {
        var id: String {
            sourceId
        }
        
        static func == (lhs: StateGraph.Edge, rhs: StateGraph.Edge) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            id.hash(into: &hasher)
        }
        
        var sourceId: String
        var target: EdgeValue
    }

    private var edges: Set<Edge> = []
    
    /// A structure representing a node in the state graph.
    ///
    /// `Node` conforms to `Hashable` and `Identifiable` protocols.
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

    private var entryPoint: EdgeValue?

    private var stateFactory: StateFactory<State>
    private var channels: Channels
    
    private var compileConfig: CompileConfig?
    
    /// Initializes a new instance of `StateGraph`.
    ///
    /// - Parameters:
    ///    - channels: A dictionary representing the channels in the graph.
    ///    - stateFactory: A closure that provides the state factory for creating agent states.
    public init( channels: Channels = [:], stateFactory: @escaping StateFactory<State> ) {
        self.channels = channels
        self.stateFactory = stateFactory
    }
    
    /// Adds a node to the state graph.
    ///
    /// - Parameters:
    ///    - id: The identifier of the node.
    ///    - action: A closure representing the action to be performed on the node.
    /// - Throws: An error if the node identifier is invalid or if a node with the same identifier already exists.
    @discardableResult
    public func addNode( _ id: String, action: @escaping NodeAction<State> ) throws -> Self {
        guard id != END else {
            throw StateGraphError.invalidNodeIdentifier( "END is not a valid node id!")
        }
        let node = Node(id: id, action: action)
        if nodes.contains(node) {
            throw StateGraphError.duplicateNodeError("node with id:\(id) already exist!")
        }
        nodes.insert( node )
        return self
    }
    
    /**
     Adds a node to the state graph, representing a subgraph.

     This method allows the creation of a node in the state graph that is associated with
     a precompiled subgraph (`StateGraph.CompiledGraph`). The node's action will invoke
     the subgraph and return its output as part of the current graph's execution.

     - Parameters:
        - id: A `String` representing the identifier of the node to be added.
        - subgraph: An instance of `StateGraph.CompiledGraph` representing the subgraph to be executed by this node.
     - Throws:
        - `StateGraphError.duplicateNodeError` if a node with the same identifier already exists.
     
     - Note: The subgraph's outputs are represented as an embedded stream within the current graph's execution.
     */
    @discardableResult
    public func addNode(_ id: String, subgraph: StateGraph<State>.CompiledGraph) throws -> Self {
        // Create a new node with the specified ID. Its action invokes the subgraph
        // and streams its output as part of the state graph's execution.
        let node = Node(id: id, action: { state in
            return ["_subgraph": subgraph.stream( .args(state.data) ) ]
        })
        
        // Check if a node with the same ID already exists, throwing an error if so.
        if nodes.contains(node) {
            throw StateGraphError.duplicateNodeError("node with id:\(id) already exist!")
        }
        
        // Add the newly created node to the set of nodes in the state graph.
        nodes.insert(node)
        return self
    }

    /// Adds an edge to the state graph.
    ///
    /// - Parameters:
    ///    - sourceId: The identifier of the source node.
    ///    - targetId: The identifier of the target node.
    /// - Throws: An error if the edge identifiers are invalid or if an edge with the same source identifier already exists.
    @discardableResult
    public func addEdge( sourceId: String, targetId: String ) throws -> Self {
        guard sourceId != END else {
            throw StateGraphError.invalidEdgeIdentifier( "END is not a valid edge sourceId!")
        }
        guard sourceId != START else {
            if targetId == END  {
                throw StateGraphError.invalidNodeIdentifier( "END is not a valid node entry point!")
            }
            entryPoint = EdgeValue.id(targetId)
            return self
        }

        let edge = Edge(sourceId: sourceId, target: .id(targetId) )
        if edges.contains(edge) {
            throw StateGraphError.duplicateEdgeError("edge with id:\(sourceId) already exist!")
        }
        edges.insert( edge )
        return self
    }
    
    /// Adds a conditional edge to the state graph.
    ///
    /// - Parameters:
    ///    - sourceId: The identifier of the source node.
    ///    - condition: A closure representing the condition to be checked on the edge.
    ///    - edgeMapping: A dictionary representing the edge mappings.
    /// - Throws: An error if the edge identifiers are invalid or if the edge mapping is empty.
    @discardableResult
    public func addConditionalEdge( sourceId: String, condition: @escaping EdgeCondition<State>, edgeMapping: [String:String] ) throws -> Self {
        guard sourceId != END else {
            throw StateGraphError.invalidEdgeIdentifier( "END is not a valid edge sourceId!")
        }
        if edgeMapping.isEmpty {
            throw StateGraphError.edgeMappingIsEmpty
        }
        guard sourceId != START else {
            entryPoint = EdgeValue.condition((condition, edgeMapping))
            return self
        }

        let edge = Edge(sourceId: sourceId, target: .condition(( condition, edgeMapping)) )
        if edges.contains(edge) {
            throw StateGraphError.duplicateEdgeError("edge with id:\(sourceId) already exist!")
        }
        edges.insert( edge)
        return self
    }
    
    /// Sets the entry point of the state graph.
    ///
    /// - Parameter nodeId: The identifier of the entry point node.
    /// - Throws: An error if the entry point is invalid.
    @available(*, deprecated, message: "This method is deprecated. Use `addEdge( START, nodeId )` instead.")
    public func setEntryPoint( _ nodeId: String ) throws {
        let _ = try addEdge( sourceId: START, targetId: nodeId )
    }

    /// Sets the conditional entry point of the state graph.
    ///
    /// - Parameters:
    ///    - condition: A closure representing the condition to be checked on the edge.
    ///    - edgeMapping: A dictionary representing the edge mappings.
    /// - Throws: An error if the entry point is invalid.
    @available(*, deprecated, message: "This method is deprecated. Use `addConditionalEdge( START, condition, edgeMappings )` instead.")
    public func setConditionalEntryPoint( condition: @escaping EdgeCondition<State>, edgeMapping: [String:String] ) throws {
        let _ = try self.addConditionalEdge(sourceId: START, condition: condition, edgeMapping: edgeMapping )
    }
        
    private var fakeAction: NodeAction<State> = { _ in return [:] }

    private func makeFakeNode( _ id: String ) -> Node {
        Node(id: id, action: fakeAction)
    }
    
    /// Compiles the state graph into a `CompiledGraph`.
    ///
    /// - Throws: An error if the entry point or finish point is invalid, or if there are missing nodes referenced by edges.
    /// - Returns: A `CompiledGraph` instance representing the compiled state graph.
    public func compile( config: CompileConfig? = nil ) throws -> CompiledGraph {
        
        if let config {
            self.compileConfig = config
            
            for interruption in config.interruptionsBefore {
                
                guard nodes.first( where: { $0.id == interruption } ) != nil else  {
                    throw StateGraphError.missingNodeInEdgeMapping( "interruptionBefore contains a not existent nodeId \(interruption)!")
                }
            }
        }
        
        guard let entryPoint else {
            throw StateGraphError.missingEntryPoint
        }
        
        switch( entryPoint ) {
            case .id( let targetId ):
                guard nodes.contains( makeFakeNode( targetId ) ) else {
                    throw StateGraphError.entryPointNotExist( "entryPoint: \(targetId) doesn't exist!")
                }
            break
            case .condition((_, let edgeMappings)):
                for (_,nodeId) in edgeMappings {
                    guard nodeId == END || nodes.contains(makeFakeNode(nodeId) ) else {
                        throw StateGraphError.missingNodeInEdgeMapping( "edge mapping for entryPoint contains a not existent nodeId \(nodeId)!")
                    }
                }
            break
        }
                
        for edge in edges {
            guard nodes.contains( makeFakeNode(edge.sourceId) ) else {
                throw StateGraphError.missingNodeReferencedByEdge( "edge sourceId: \(edge.sourceId) reference to non existent node!")
            }

            switch( edge.target ) {
            case .id( let targetId ):
                guard targetId == END || nodes.contains(makeFakeNode(targetId) ) else {
                    throw StateGraphError.missingNodeReferencedByEdge( "edge sourceId: \(edge.sourceId) reference to non existent node targetId: \(targetId) node!")
                }
                break
            case .condition((_, let edgeMappings)):
                for (_,nodeId) in edgeMappings {
                    guard nodeId == END || nodes.contains(makeFakeNode(nodeId) ) else {
                        throw StateGraphError.missingNodeInEdgeMapping( "edge mapping for sourceId: \(edge.sourceId) contains a not existent nodeId \(nodeId)!")
                    }
                }
            }
        }
        
        return CompiledGraph( owner: self )
    }
}


extension StateGraph {
    
    /**
     A class representing a compiled state graph.
     
     The `CompiledGraph` class is responsible for managing the state transitions and actions
     within a state graph. It initializes the state data, updates partial states, merges states,
     and determines the next node in the graph based on conditions and mappings.
     
     - Note: This class is intended to be used internally by the `StateGraph` class.
     */
    public class CompiledGraph {
    
        var compileConfig: CompileConfig?
        
        /// A factory for creating agent states.
        var stateFactory: StateFactory<State>
        
        /// A dictionary mapping node IDs to their corresponding actions.
        var nodes: Dictionary<String, NodeAction<State>>
        
        /// A dictionary mapping edge source IDs to their corresponding edge values.
        var edges: Dictionary<String, EdgeValue>
        
        /// The entry point of the graph.
        var entryPoint: EdgeValue
        
        /// The schema representing the channels in the graph.
        let schema: Channels
        
        /**
         Initializes a new instance of `CompiledGraph`.
         
         - Parameter owner: The `StateGraph` instance that owns this compiled graph.
         */
        init(owner: StateGraph) {
            self.schema = owner.channels
            self.stateFactory = owner.stateFactory
            self.nodes = Dictionary()
            self.edges = Dictionary()
            self.entryPoint = owner.entryPoint!
            self.compileConfig = owner.compileConfig
            
            owner.nodes.forEach { [unowned self] node in
                nodes[node.id] = node.action
            }
            
            owner.edges.forEach { [unowned self] edge in
                edges[edge.sourceId] = edge.target
            }
        }
        
        /**
         Initializes the state data from the schema.
         
         - Returns: A dictionary representing the initial state data.
         */
        private func initStateDataFromSchema() throws -> [String: Any] {
            let mappedValues = try schema.compactMap { key, channel in
                if let def = channel.`default` {
                    return (key, try def())
                }
                return nil
            }
            
            return Dictionary(uniqueKeysWithValues: mappedValues)
        }
        
        /**
         Updates the partial state from the schema.
         
         - Parameters:
            - currentState: The current state of the agent.
            - partialState: The partial state to be updated.
         - Throws: An error if the update fails.
         - Returns: The updated partial state.
         */
        private func updatePartialStateFromSchema(currentState: State, partialState: PartialAgentState) throws -> PartialAgentState {
            return try currentState.updateStateData(partialState: partialState, channels: schema)
        }
        
        /**
         Merges the current state with the partial state.
         
         - Parameters:
            - currentState: The current state of the agent.
            - partialState: The partial state to be merged.
         - Throws: An error if the merge fails.
         - Returns: The merged state.
         */
        private func mergeState(currentState: State, partialState: PartialAgentState) throws -> State {
            if partialState.isEmpty {
                return currentState
            }
            
            let partialSchemaUpdated = try updatePartialStateFromSchema(currentState: currentState, partialState: partialState)
            
            let newState = currentState.data.merging(partialSchemaUpdated, uniquingKeysWith: { (current, new) in
                return new
            })
            return State.init(newState)
        }
        
        /**
         Determines the next node ID based on the given route and agent state.
         
         - Parameters:
            - route: The edge value representing the route.
            - agentState: The current state of the agent.
            - nodeId: The current node ID.
         - Throws: An error if the next node ID cannot be determined.
         - Returns: The next node ID.
         */
        private func fetchNextNodeId(route: EdgeValue?, agentState: State, nodeId: String) async throws -> String {
            guard let route else {
                throw CompiledGraphError.missingEdge("edge with node: \(nodeId) not found!")
            }
            
            switch(route) {
            case .id(let nextNodeId):
                return nextNodeId
            case .condition(let (condition, mapping)):
                let newRoute = try await condition(agentState)
                guard let result = mapping[newRoute] else {
                    throw CompiledGraphError.missingNodeInEdgeMapping("cannot find edge mapping for id: \(newRoute) in conditional edge with sourceId:\(nodeId)")
                }
                return result
            }
        }

        /**
         Determines the next node ID based on the current node ID and agent state.
         
         - Parameters:
            - nodeId: The current node ID.
            - agentState: The current state of the agent.
         - Throws: An error if the next node ID cannot be determined.
         - Returns: The next node ID.
         */
        private func fetchNextNodeId(nodeId: String, agentState: State) async throws -> String {
            try await fetchNextNodeId(route: edges[nodeId], agentState: agentState, nodeId: nodeId)
        }

        /**
         Determines the entry point of the graph based on the agent state.
         
         - Parameter agentState: The current state of the agent.
         - Throws: An error if the entry point cannot be determined.
         - Returns: The entry point node ID.
         */
        private func getEntryPoint(agentState: State) async throws -> String {
            try await fetchNextNodeId(route: self.entryPoint, agentState: agentState, nodeId: "entryPoint")
        }

        /**
         Finds the first embedded stream in a partial state.

         This method scans a `PartialAgentState` dictionary to find the first value that is an
         `AsyncThrowingStream` of `NodeOutput<State>`. It then returns a tuple containing the key
         associated with the stream and the stream itself.

         - Parameter partialState: A dictionary representing a partial state of the agent,
           where each key-value pair represents an attribute and its corresponding value.

         - Returns: A tuple containing the key and the embedded stream if found, or `nil`
           if no such stream exists. The stream is cast to the appropriate type
           (`AsyncThrowingStream<NodeOutput<State>, Error>`).
        */
        private func findEmbedStream( partialState:PartialAgentState ) -> (String, AsyncThrowingStream<NodeOutput<State>, Error>)? {
            
            partialState.filter { (_ , value ) in
                value is AsyncThrowingStream<NodeOutput<State>, Error>
            }.map({ (key, value ) in
                ( key, value as! AsyncThrowingStream<NodeOutput<State>, Error>)
            }).first
        }
        
        /**
         Streams the node outputs based on the given inputs.
         
         - Parameters:
            - inputs: The partial state inputs.
            - verbose: A boolean indicating whether to enable verbose logging.
         - Returns: An `AsyncThrowingStream` of `NodeOutput<State>`.
         */
        public func stream( _ input: GraphInput, config: RunnableConfig = .init() ) -> AsyncThrowingStream<NodeOutput<State>, Error> {
            let (stream, continuation) = AsyncThrowingStream.makeStream(of: NodeOutput<State>.self, throwing: Error.self)
            
            Task {
                do {
                    
                    var currentState: State
                    var currentNodeId: String
                    var nextNodeId: String
                    var isFirstStepAfterResume: Bool
                    
                    switch input {
                    case .args(let inputArgs):
                        
                        let initData = try initStateDataFromSchema()
                        
                        currentState = try mergeState(currentState: self.stateFactory(initData), partialState: inputArgs)
                        
                        currentNodeId = try await self.getEntryPoint(agentState: currentState)
                        nextNodeId = currentNodeId
                        
                        // Add Checkpoint
                        if let saver = compileConfig?.checkpointSaver {
                            
                            let _ = try saver.put(config: config,
                                                  checkpoint: .init(state: currentState.data.clone(),
                                                        nodeId: START,
                                                        nextNodeId: currentNodeId))
                        }

                        isFirstStepAfterResume = false
                    case .resume:
                        print("Resuming the stream now")
                        guard let saver = compileConfig?.checkpointSaver else {
                            throw CompiledGraphError.executionError("Resume request without a checkpoint saver!")
                        }
                        guard let startCheckpoint = saver.get( config: config ) else {
                            throw CompiledGraphError.executionError("Resume request without a checkpoint!")
                        }
                        
                        currentState = stateFactory(startCheckpoint.state);
                        
                        currentNodeId = startCheckpoint.nodeId
                        nextNodeId = startCheckpoint.nextNodeId
                        print("Current nodeId: \(currentNodeId), nextNodeId \(nextNodeId)")
                        
                        isFirstStepAfterResume = true
                    }
                    
                    repeat {
                        
                        if let interruptionsBefore = compileConfig?.interruptionsBefore  {
                            if( !isFirstStepAfterResume && interruptionsBefore.contains(nextNodeId) ) {
                                break;
                            }
                            isFirstStepAfterResume = false
                        }
                        
                        currentNodeId = nextNodeId;

                        guard let action = nodes[currentNodeId] else {
                            continuation.finish(throwing: CompiledGraphError.missingNode("node: \(currentNodeId) not found!"))
                            break
                        }
                        
                        if( config.verbose) {
                            log.debug("start processing node \(currentNodeId)")
                        }
                        
                        try Task.checkCancellation()
                        let partialState = try await action(currentState)
                        
                        // Support embed stream
                        if let (key, embed ) = findEmbedStream(partialState: partialState) {
                            var currentStateEmbed:State?
                            for try await output in embed {
                                try Task.checkCancellation()
                                continuation.yield(output)
                                currentStateEmbed = output.state
                            }
                            guard let currentStateEmbed  else {
                                continuation.finish(throwing: CompiledGraphError.executionError("failed iterate on embed stream! last state is nil"))
                                return
                            }
                            currentState = try mergeState(currentState: currentStateEmbed,
                                                          partialState: partialState.filter( { $0.key != key } ))
                        }
                        else {
                            currentState = try mergeState(currentState: currentState,
                                                          partialState: partialState)
                        }
                        

                        let output = NodeOutput(node: currentNodeId, state: currentState)
                        
                        try Task.checkCancellation()
                        
                        nextNodeId = try await fetchNextNodeId(nodeId: currentNodeId, agentState: currentState)
                        
                        // Add Checkpoint
                        if let saver = compileConfig?.checkpointSaver {
                            
                            let _ = try saver.put(config: config,
                                                  checkpoint: .init(state: currentState.data.clone(),
                                                        nodeId: currentNodeId,
                                                        nextNodeId: nextNodeId))
                        }
                        
                        continuation.yield(output)
                        

                    } while(nextNodeId != END && !Task.isCancelled)
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            return stream
        }
        
        /**
         Runs the graph and returns the final state.
         
         - Parameters:
            - inputs: The partial state inputs.
            - verbose: A boolean indicating whether to enable verbose logging.
         - Throws: An error if the invocation fails.
         - Returns: The final state.
         */
        public func invoke( _ input: GraphInput, config: RunnableConfig = .init() ) async throws -> State {
            let initResult: [NodeOutput<State>] = []
            let result = try await stream( input, config: config ).reduce(initResult, { partialResult, output in
                [output]
            })
            if result.isEmpty {
                throw CompiledGraphError.executionError("no state has been produced! probably processing has been interrupted")
            }
            return result[0].state
        }
        
        /**
         Updates the state in the checkpoint with new partial values and optionally redirects to a different node.

         This method fetches the current checkpoint using the provided configuration, applies the new partial state
         values to the checkpoint, and optionally uses the `asNode` parameter to compute the next node ID.
         It then stores the updated checkpoint and returns a modified `RunnableConfig` pointing to the updated checkpoint.

         - Parameters:
            - config: The current runnable configuration used to locate the checkpoint.
            - values: A dictionary representing the partial state values to be applied.
            - asNode: An optional node ID indicating which node's transition should be used to determine the next node.

         - Throws: `CompiledGraphError.executionError` if the checkpoint saver or the checkpoint is missing,
                   or if the next node cannot be resolved.

         - Returns: A new `RunnableConfig` updated with the new checkpoint ID and next node ID.
         */
        public func updateState( config: RunnableConfig, values: PartialAgentState, asNode: String? = nil ) async throws -> RunnableConfig {
            guard let saver = compileConfig?.checkpointSaver else {
                throw CompiledGraphError.executionError("Missing checkpoint saver!")
            }
            guard let checkpoint = saver.get( config: config ) else {
                throw CompiledGraphError.executionError("Missing checkpoint!")
            }

            let branchCheckpoint = try checkpoint.updateState(values: values, channels: schema)

            var nextNodeId = branchCheckpoint.nextNodeId
            if let asNode {
                nextNodeId = try await fetchNextNodeId( nodeId: asNode, agentState: stateFactory(branchCheckpoint.state) );
            }
            
            // update checkpoint in saver
            let newConfig = try saver.put( config: config, checkpoint: branchCheckpoint );

            return newConfig.with {
                $0.nextNodeId = nextNodeId
            }
        }

        
        
    }


}

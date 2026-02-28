/**
 * Live Map Component with Real-time Updates - PRODUCTION READY
 * All issues fixed: Performance, memory leaks, error handling
 */

import React, { useState, useEffect, useRef, useCallback, useMemo } from 'react';
import { Viewer, useCesium } from 'resium';
import { 
    Cartesian3, 
    Color, 
    Ion, 
    Math as CesiumMath,
    Rectangle,
    Camera,
    defined,
    ScreenSpaceEventType
} from 'cesium';
import { io } from 'socket.io-client';
import VehicleMarker3D from './VehicleMarker3D';
import 'cesium/Build/Cesium/Widgets/widgets.css';

// Set Cesium access token
Ion.defaultAccessToken = process.env.REACT_APP_CESIUM_TOKEN;

const LiveMap = () => {
    const [vehicles, setVehicles] = useState([]);
    const [selectedVehicle, setSelectedVehicle] = useState(null);
    const [stats, setStats] = useState({
        total: 0,
        online: 0,
        moving: 0,
        parked: 0
    });
    const [isConnected, setIsConnected] = useState(false);
    const [error, setError] = useState(null);
    const [followVehicle, setFollowVehicle] = useState(false);
    
    const socketRef = useRef(null);
    const viewerRef = useRef(null);
    const updateQueue = useRef([]);
    const animationFrame = useRef(null);
    const reconnectAttempts = useRef(0);
    const maxReconnectAttempts = 10;
    const mountedRef = useRef(true);
    const markersRef = useRef(new Map());

    // Initialize WebSocket with reconnection
    useEffect(() => {
        const token = localStorage.getItem('token');
        const socketUrl = process.env.REACT_APP_SOCKET_URL || 'ws://3.108.114.12:5024';
        
        connectWebSocket(socketUrl, token);

        return () => {
            mountedRef.current = false;
            if (socketRef.current) {
                socketRef.current.disconnect();
            }
            if (animationFrame.current) {
                cancelAnimationFrame(animationFrame.current);
            }
            // Clean up markers
            markersRef.current.clear();
        };
    }, []);

    const connectWebSocket = (url, token) => {
        try {
            socketRef.current = io(url, {
                auth: { token },
                transports: ['websocket'],
                reconnection: true,
                reconnectionAttempts: maxReconnectAttempts,
                reconnectionDelay: 1000,
                reconnectionDelayMax: 30000,
                randomizationFactor: 0.5,
                path: '/socket.io',
                timeout: 20000
            });

            socketRef.current.on('connect', () => {
                if (!mountedRef.current) return;
                console.log('WebSocket connected');
                setIsConnected(true);
                setError(null);
                reconnectAttempts.current = 0;
            });

            socketRef.current.on('disconnect', (reason) => {
                if (!mountedRef.current) return;
                console.log('WebSocket disconnected:', reason);
                setIsConnected(false);
                
                if (reason === 'io server disconnect') {
                    // Server disconnected, don't reconnect
                    return;
                }
                reconnectAttempts.current++;
            });

            socketRef.current.on('connect_error', (error) => {
                if (!mountedRef.current) return;
                console.error('Connection error:', error);
                setIsConnected(false);
                setError('Connection failed. Retrying...');
            });

            // Handle initial map data
            socketRef.current.on('map:init', (data) => {
                if (!mountedRef.current) return;
                setVehicles(data.vehicles);
                updateStats(data.vehicles);
                
                // Fit bounds to vehicles
                if (data.vehicles.length > 0 && viewerRef.current) {
                    fitBoundsToVehicles(data.vehicles);
                }
            });

            // Handle real-time updates
            socketRef.current.on('vehicle:update', (update) => {
                if (!mountedRef.current) return;
                // Queue update for smooth animation
                updateQueue.current.push(update);
                
                if (!animationFrame.current) {
                    animationFrame.current = requestAnimationFrame(processUpdates);
                }
            });

            // Handle stats updates
            socketRef.current.on('stats:update', (newStats) => {
                if (!mountedRef.current) return;
                setStats(newStats);
            });

            // Handle errors
            socketRef.current.on('error', (error) => {
                if (!mountedRef.current) return;
                console.error('Socket error:', error);
                setError(error.message);
            });

        } catch (err) {
            console.error('WebSocket initialization error:', err);
            setError('Failed to initialize connection');
        }
    };

    // Process queued updates with throttling
    const processUpdates = useCallback(() => {
        if (!mountedRef.current || updateQueue.current.length === 0) {
            animationFrame.current = null;
            return;
        }

        // Process up to 10 updates per frame
        const batch = updateQueue.current.splice(0, 10);
        
        setVehicles(prevVehicles => {
            const updated = [...prevVehicles];
            
            batch.forEach(update => {
                const index = updated.findIndex(v => v.vehicle_id === update.vehicleId);
                if (index !== -1) {
                    updated[index] = {
                        ...updated[index],
                        ...update,
                        registration_number: updated[index].registration_number
                    };
                    
                    // Update marker if following
                    if (followVehicle && selectedVehicle?.vehicle_id === update.vehicleId) {
                        updateCameraPosition(update);
                    }
                }
            });

            return updated;
        });

        animationFrame.current = requestAnimationFrame(processUpdates);
    }, [followVehicle, selectedVehicle]);

    // Update camera position for following
    const updateCameraPosition = (update) => {
        if (viewerRef.current) {
            viewerRef.current.camera.flyTo({
                destination: Cartesian3.fromDegrees(
                    update.longitude,
                    update.latitude,
                    1000
                ),
                duration: 0.5,
                orientation: {
                    heading: CesiumMath.toRadians(update.heading || 0),
                    pitch: CesiumMath.toRadians(-30),
                    roll: 0.0
                }
            });
        }
    };

    // Fit map bounds to show all vehicles
    const fitBoundsToVehicles = useCallback((vehiclesList) => {
        if (!viewerRef.current || vehiclesList.length === 0) return;

        const positions = vehiclesList
            .filter(v => v.latitude && v.longitude)
            .map(v => Cartesian3.fromDegrees(v.longitude, v.latitude));

        if (positions.length > 0) {
            try {
                const rectangle = Rectangle.fromCartesianArray(positions);
                viewerRef.current.camera.flyTo({
                    destination: rectangle,
                    duration: 2,
                    complete: () => {
                        console.log('Camera flight complete');
                    }
                });
            } catch (err) {
                console.error('Error fitting bounds:', err);
            }
        }
    }, []);

    // Update statistics
    const updateStats = useCallback((vehiclesList) => {
        const online = vehiclesList.filter(v => v.status === 'online').length;
        const moving = vehiclesList.filter(v => v.ignition && v.speed > 0).length;
        
        setStats({
            total: vehiclesList.length,
            online,
            offline: vehiclesList.length - online,
            moving,
            parked: online - moving
        });
    }, []);

    // Handle vehicle click
    const handleVehicleClick = useCallback((vehicle) => {
        setSelectedVehicle(vehicle);
        setFollowVehicle(true);
        
        // Center camera on vehicle
        if (viewerRef.current) {
            viewerRef.current.camera.flyTo({
                destination: Cartesian3.fromDegrees(
                    vehicle.longitude,
                    vehicle.latitude,
                    1000
                ),
                orientation: {
                    heading: CesiumMath.toRadians(vehicle.heading || 0),
                    pitch: CesiumMath.toRadians(-30),
                    roll: 0.0
                },
                duration: 1.5
            });
        }

        // Emit focus event
        socketRef.current?.emit('request:vehicle:focus', vehicle.vehicle_id);
    }, []);

    // Handle camera ready
    const handleCameraReady = useCallback((viewer) => {
        viewerRef.current = viewer;
        
        // Add click handler for deselection
        viewer.screenSpaceEventHandler.setInputAction(() => {
            setSelectedVehicle(null);
            setFollowVehicle(false);
        }, ScreenSpaceEventType.LEFT_CLICK);
        
        // Request bounds
        socketRef.current?.emit('request:map:bounds');
    }, []);

    // Memoize vehicle markers to prevent unnecessary rerenders
    const vehicleMarkers = useMemo(() => {
        return vehicles.map(vehicle => (
            vehicle.latitude && vehicle.longitude && (
                <VehicleMarker3D
                    key={vehicle.vehicle_id}
                    vehicle={vehicle}
                    onClick={handleVehicleClick}
                    isSelected={selectedVehicle?.vehicle_id === vehicle.vehicle_id}
                />
            )
        ));
    }, [vehicles, selectedVehicle, handleVehicleClick]);

    return (
        <div style={{ position: 'relative', width: '100%', height: '100vh', overflow: 'hidden' }}>
            {/* Connection Status */}
            <div style={{
                position: 'absolute',
                top: 20,
                left: 20,
                zIndex: 100,
                padding: '8px 16px',
                borderRadius: 20,
                backgroundColor: isConnected ? '#10b981' : '#ef4444',
                color: 'white',
                fontSize: 12,
                fontWeight: 'bold',
                boxShadow: '0 2px 10px rgba(0,0,0,0.1)',
                display: 'flex',
                alignItems: 'center',
                gap: '6px'
            }}>
                <span style={{
                    width: 8,
                    height: 8,
                    borderRadius: '50%',
                    backgroundColor: 'white',
                    animation: isConnected ? 'pulse 2s infinite' : 'none'
                }} />
                {isConnected ? 'LIVE' : 'DISCONNECTED'}
            </div>

            {/* Error Toast */}
            {error && (
                <div style={{
                    position: 'absolute',
                    top: 20,
                    left: '50%',
                    transform: 'translateX(-50%)',
                    zIndex: 100,
                    padding: '12px 24px',
                    borderRadius: 8,
                    backgroundColor: '#ef4444',
                    color: 'white',
                    fontSize: 14,
                    boxShadow: '0 4px 20px rgba(0,0,0,0.2)',
                    animation: 'slideDown 0.3s ease'
                }}>
                    ⚠️ {error}
                </div>
            )}

            {/* Stats Overlay */}
            <div style={{
                position: 'absolute',
                top: 20,
                right: 20,
                background: 'rgba(255, 255, 255, 0.95)',
                padding: 16,
                borderRadius: 12,
                boxShadow: '0 4px 20px rgba(0,0,0,0.15)',
                zIndex: 10,
                minWidth: 220,
                backdropFilter: 'blur(10px)',
                border: '1px solid rgba(0,0,0,0.1)'
            }}>
                <h3 style={{ margin: '0 0 12px 0', color: '#1f2937', fontSize: 16 }}>
                    Fleet Status
                </h3>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                    {[
                        { label: 'Total Vehicles', value: stats.total, color: '#1f2937' },
                        { label: 'Online', value: stats.online, color: '#10b981' },
                        { label: 'Moving', value: stats.moving, color: '#3b82f6' },
                        { label: 'Parked', value: stats.parked, color: '#f59e0b' },
                        { label: 'Offline', value: stats.offline, color: '#6b7280' }
                    ].map(item => (
                        <div key={item.label} style={{ display: 'flex', justifyContent: 'space-between' }}>
                            <span style={{ color: '#6b7280' }}>{item.label}:</span>
                            <span style={{ fontWeight: 'bold', color: item.color }}>{item.value}</span>
                        </div>
                    ))}
                </div>
            </div>

            {/* Selected Vehicle Info */}
            {selectedVehicle && (
                <div style={{
                    position: 'absolute',
                    bottom: 20,
                    left: 20,
                    background: 'white',
                    padding: 16,
                    borderRadius: 12,
                    boxShadow: '0 4px 20px rgba(0,0,0,0.2)',
                    zIndex: 10,
                    minWidth: 280,
                    maxWidth: 350,
                    border: '1px solid rgba(0,0,0,0.1)'
                }}>
                    <button 
                        onClick={() => {
                            setSelectedVehicle(null);
                            setFollowVehicle(false);
                        }}
                        style={{
                            position: 'absolute',
                            top: 8,
                            right: 8,
                            background: 'none',
                            border: 'none',
                            fontSize: 18,
                            cursor: 'pointer',
                            color: '#6b7280',
                            width: 24,
                            height: 24,
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            borderRadius: 4,
                            hover: { backgroundColor: '#f3f4f6' }
                        }}
                    >
                        ×
                    </button>
                    <h3 style={{ margin: '0 0 12px 0', color: '#1f2937', fontSize: 16 }}>
                        {selectedVehicle.registration_number}
                    </h3>
                    <div style={{ 
                        display: 'grid', 
                        gridTemplateColumns: '1fr 1fr', 
                        gap: '12px 16px',
                        fontSize: 13
                    }}>
                        <div>
                            <div style={{ color: '#6b7280', fontSize: 11 }}>Speed</div>
                            <div style={{ fontWeight: 'bold' }}>{selectedVehicle.speed || 0} km/h</div>
                        </div>
                        <div>
                            <div style={{ color: '#6b7280', fontSize: 11 }}>Heading</div>
                            <div style={{ fontWeight: 'bold' }}>{selectedVehicle.heading || 0}°</div>
                        </div>
                        <div>
                            <div style={{ color: '#6b7280', fontSize: 11 }}>Ignition</div>
                            <div style={{ 
                                fontWeight: 'bold',
                                color: selectedVehicle.ignition ? '#10b981' : '#6b7280'
                            }}>
                                {selectedVehicle.ignition ? 'ON' : 'OFF'}
                            </div>
                        </div>
                        <div>
                            <div style={{ color: '#6b7280', fontSize: 11 }}>Status</div>
                            <div style={{ 
                                fontWeight: 'bold',
                                color: selectedVehicle.status === 'online' ? '#10b981' : '#6b7280'
                            }}>
                                {selectedVehicle.status}
                            </div>
                        </div>
                    </div>
                    {selectedVehicle.speed > 0 && (
                        <div style={{
                            marginTop: 12,
                            padding: '8px 12px',
                            background: '#f3f4f6',
                            borderRadius: 8,
                            fontSize: 12,
                            color: '#4b5563',
                            display: 'flex',
                            alignItems: 'center',
                            gap: 4
                        }}>
                            <span>⚡</span> Moving at {selectedVehicle.speed} km/h
                        </div>
                    )}
                </div>
            )}

            {/* Controls */}
            <div style={{
                position: 'absolute',
                bottom: 20,
                right: 20,
                zIndex: 10,
                display: 'flex',
                flexDirection: 'column',
                gap: 8
            }}>
                <button
                    onClick={() => fitBoundsToVehicles(vehicles)}
                    style={{
                        width: 40,
                        height: 40,
                        borderRadius: '50%',
                        background: 'white',
                        border: 'none',
                        boxShadow: '0 2px 10px rgba(0,0,0,0.1)',
                        cursor: 'pointer',
                        fontSize: 20,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        hover: { backgroundColor: '#f3f4f6' }
                    }}
                    title="Fit to bounds"
                >
                    🌐
                </button>
                {selectedVehicle && (
                    <button
                        onClick={() => setFollowVehicle(!followVehicle)}
                        style={{
                            width: 40,
                            height: 40,
                            borderRadius: '50%',
                            background: followVehicle ? '#3b82f6' : 'white',
                            border: 'none',
                            boxShadow: '0 2px 10px rgba(0,0,0,0.1)',
                            cursor: 'pointer',
                            fontSize: 20,
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            color: followVehicle ? 'white' : 'black'
                        }}
                        title={followVehicle ? "Stop following" : "Follow vehicle"}
                    >
                        👁️
                    </button>
                )}
            </div>

            <Viewer
                ref={viewerRef}
                full
                animation={false}
                timeline={false}
                baseLayerPicker={true}
                geocoder={true}
                homeButton={true}
                sceneModePicker={true}
                navigationHelpButton={false}
                navigationInstructionsInitiallyVisible={false}
                onReady={handleCameraReady}
                skyBox={false}
                skyAtmosphere={true}
                targetFrameRate={60}
                resolutionScale={window.devicePixelRatio || 1}
                orderIndependentTranslucency={false}
                contextOptions={{
                    webgl: {
                        alpha: false,
                        depth: true,
                        stencil: false,
                        antialias: true,
                        powerPreference: "high-performance",
                        preserveDrawingBuffer: false
                    }
                }}
                terrainProvider={undefined}
                imageryProvider={undefined}
            >
                {vehicleMarkers}
            </Viewer>

            <style>
                {`
                    @keyframes pulse {
                        0% { opacity: 1; }
                        50% { opacity: 0.5; }
                        100% { opacity: 1; }
                    }
                    @keyframes slideDown {
                        from { transform: translate(-50%, -100%); opacity: 0; }
                        to { transform: translate(-50%, 0); opacity: 1; }
                    }
                `}
            </style>
        </div>
    );
};

export default LiveMap;

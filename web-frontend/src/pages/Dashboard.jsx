import React, { useState, useEffect } from 'react';
import LiveMap from '../components/LiveMap';

const Dashboard = () => {
  const [locations, setLocations] = useState([]);

  useEffect(() => {
    fetch('http://3.108.114.12:5024/api/map/live').then(res => res.json()).then(setLocations);

    const ws = new WebSocket('ws://3.108.114.12:5024');
    ws.onmessage = (event) => {
      const update = JSON.parse(event.data);
      setLocations(prev => prev.map(loc => loc.deviceId === update.deviceId ? update : loc));
    };
    return () => ws.close();
  }, []);

  return <LiveMap locations={locations} />;
};

export default Dashboard;

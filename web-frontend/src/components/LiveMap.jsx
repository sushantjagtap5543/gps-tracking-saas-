import React from 'react';
import { Viewer } from 'resium';
import { Ion } from 'cesium';

Ion.defaultAccessToken = process.env.CESIUM_TOKEN;

const LiveMap = ({ locations }) => {
  return (
    <Viewer full>
      {locations.map((loc) => (
        <Entity key={loc.deviceId} position={Cartesian3.fromDegrees(loc.lng, loc.lat)} billboard={{ image: '/vehicle-icon.png' }} orientation={HeadingPitchRoll.fromDegrees(loc.heading, 0, 0)} />
      ))}
    </Viewer>
  );
};

export default LiveMap;

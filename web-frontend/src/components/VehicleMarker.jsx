import React from 'react';
import { Entity } from 'resium';
import { Cartesian3, HeadingPitchRoll } from 'cesium';

const VehicleMarker = ({ loc }) => (
  <Entity position={Cartesian3.fromDegrees(loc.lng, loc.lat)} billboard={{ image: '/vehicle-icon.png' }} orientation={HeadingPitchRoll.fromDegrees(loc.heading, 0, 0)} />
);

export default VehicleMarker;

import { useEffect, useState } from "react";
import API from "../api";
import Navbar from "../components/Navbar";

export default function Dashboard() {
  const [vehicles, setVehicles] = useState([]);

  useEffect(() => {
    API.get("/vehicles")
      .then((res) => setVehicles(res.data))
      .catch(() => alert("Failed to load vehicles"));
  }, []);

  return (
    <>
      <Navbar />
      <div style={{ padding: 20 }}>
        <h2>Dashboard</h2>
        {vehicles.map((v) => (
          <div key={v.id}>
            {v.name} - {v.status}
          </div>
        ))}
      </div>
    </>
  );
}

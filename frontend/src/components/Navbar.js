import { useContext } from "react";
import { AuthContext } from "../context/AuthContext";
import { Link } from "react-router-dom";

export default function Navbar() {
  const { logout } = useContext(AuthContext);

  return (
    <nav style={{ padding: 20, background: "#222", color: "#fff" }}>
      <Link to="/dashboard" style={{ marginRight: 20, color: "#fff" }}>
        Dashboard
      </Link>
      <Link to="/vehicles" style={{ marginRight: 20, color: "#fff" }}>
        Vehicles
      </Link>
      <button onClick={logout}>Logout</button>
    </nav>
  );
}

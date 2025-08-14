import { Routes, Route } from 'react-router-dom'
import Layout from './components/Layout'
import Dashboard from './pages/Dashboard-minimal'
import Status from './pages/Status'

function App() {
  return (
    <Layout>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/status" element={<Status />} />
      </Routes>
    </Layout>
  )
}

export default App
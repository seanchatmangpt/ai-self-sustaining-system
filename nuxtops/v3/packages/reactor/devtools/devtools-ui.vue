<template>
  <div class="reactor-devtools">
    <!-- Header -->
    <div class="header">
      <h2>🚀 Nuxt Reactor DevTools</h2>
      <div class="header-actions">
        <button @click="refreshData" :disabled="loading">
          <Icon name="carbon:refresh" />
          Refresh
        </button>
        <button @click="clearHistory">
          <Icon name="carbon:trash-can" />
          Clear History
        </button>
        <button @click="exportData">
          <Icon name="carbon:download" />
          Export
        </button>
      </div>
    </div>

    <!-- Performance Overview -->
    <div class="performance-overview">
      <div class="metric-card">
        <div class="metric-value">{{ performance.totalExecutions }}</div>
        <div class="metric-label">Total Executions</div>
      </div>
      <div class="metric-card">
        <div class="metric-value">{{ formatDuration(performance.averageDuration) }}</div>
        <div class="metric-label">Avg Duration</div>
      </div>
      <div class="metric-card">
        <div class="metric-value">{{ formatPercent(performance.successRate) }}</div>
        <div class="metric-label">Success Rate</div>
      </div>
      <div class="metric-card">
        <div class="metric-value">{{ alerts.filter(a => a.type === 'error').length }}</div>
        <div class="metric-label">Active Errors</div>
      </div>
    </div>

    <!-- Tabs -->
    <div class="tabs">
      <button 
        v-for="tab in tabs" 
        :key="tab.id"
        :class="{ active: activeTab === tab.id }"
        @click="activeTab = tab.id"
      >
        <Icon :name="tab.icon" />
        {{ tab.label }}
        <span v-if="tab.count" class="count">{{ tab.count }}</span>
      </button>
    </div>

    <!-- Tab Content -->
    <div class="tab-content">
      <!-- Reactors List -->
      <div v-if="activeTab === 'reactors'" class="reactors-tab">
        <div class="reactors-list">
          <div 
            v-for="reactor in reactors" 
            :key="reactor.id"
            :class="['reactor-item', reactor.state]"
            @click="selectedReactor = reactor"
          >
            <div class="reactor-header">
              <span class="reactor-id">{{ reactor.id }}</span>
              <span :class="['reactor-status', reactor.state]">{{ reactor.state }}</span>
              <span class="reactor-time">{{ formatTime(reactor.startTime) }}</span>
            </div>
            <div class="reactor-details">
              <span>{{ reactor.steps.length }} steps</span>
              <span v-if="reactor.duration">{{ formatDuration(reactor.duration) }}</span>
            </div>
          </div>
        </div>

        <!-- Reactor Detail Panel -->
        <div v-if="selectedReactor" class="reactor-detail">
          <h3>{{ selectedReactor.id }}</h3>
          <div class="reactor-info">
            <div><strong>State:</strong> {{ selectedReactor.state }}</div>
            <div><strong>Duration:</strong> {{ formatDuration(selectedReactor.duration) }}</div>
            <div><strong>Steps:</strong> {{ selectedReactor.steps.length }}</div>
          </div>

          <h4>Steps</h4>
          <div class="steps-list">
            <div 
              v-for="step in selectedReactor.steps" 
              :key="step.name"
              :class="['step-item', step.status]"
            >
              <Icon :name="getStepIcon(step.status)" />
              <span class="step-name">{{ step.name }}</span>
              <span v-if="step.duration" class="step-duration">{{ formatDuration(step.duration) }}</span>
              <span v-if="step.error" class="step-error">{{ step.error }}</span>
            </div>
          </div>

          <h4>Context</h4>
          <pre class="context-data">{{ JSON.stringify(selectedReactor.context, null, 2) }}</pre>
        </div>
      </div>

      <!-- Performance Tab -->
      <div v-if="activeTab === 'performance'" class="performance-tab">
        <div class="performance-controls">
          <select v-model="performanceTimeframe" @change="analyzePerformance">
            <option value="15">Last 15 minutes</option>
            <option value="60">Last hour</option>
            <option value="240">Last 4 hours</option>
            <option value="1440">Last 24 hours</option>
          </select>
          <button @click="analyzePerformance">Analyze</button>
        </div>

        <div v-if="performanceAnalysis" class="performance-analysis">
          <div class="analysis-section">
            <h4>Slowest Steps</h4>
            <div v-for="step in performanceAnalysis.slowestSteps" :key="step.name" class="analysis-item">
              <span>{{ step.name }}</span>
              <span class="value">{{ formatDuration(step.duration) }}</span>
            </div>
          </div>

          <div class="analysis-section">
            <h4>Error Patterns</h4>
            <div v-for="pattern in performanceAnalysis.errorPatterns" :key="pattern.name" class="analysis-item">
              <span>{{ pattern.name }}</span>
              <span class="value error">{{ pattern.count }} errors</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Alerts Tab -->
      <div v-if="activeTab === 'alerts'" class="alerts-tab">
        <div class="alerts-list">
          <div 
            v-for="alert in alerts" 
            :key="alert.id"
            :class="['alert-item', alert.type]"
          >
            <Icon :name="getAlertIcon(alert.type)" />
            <div class="alert-content">
              <div class="alert-message">{{ alert.message }}</div>
              <div class="alert-time">{{ formatTime(alert.timestamp) }}</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Simulator Tab -->
      <div v-if="activeTab === 'simulator'" class="simulator-tab">
        <h4>Reactor Simulator</h4>
        <p>Create and test reactor workflows without affecting your application.</p>
        
        <div class="simulator-form">
          <div class="form-group">
            <label>Reactor Name</label>
            <input v-model="simulator.name" placeholder="test-reactor" />
          </div>
          
          <div class="form-group">
            <label>Steps</label>
            <div v-for="(step, index) in simulator.steps" :key="index" class="step-form">
              <input v-model="step.name" placeholder="Step name" />
              <input v-model.number="step.duration" type="number" placeholder="Duration (ms)" />
              <label>
                <input v-model="step.shouldFail" type="checkbox" />
                Should fail
              </label>
              <button @click="simulator.steps.splice(index, 1)">Remove</button>
            </div>
            <button @click="addSimulatorStep">Add Step</button>
          </div>

          <div class="form-group">
            <label>Input Data</label>
            <textarea v-model="simulator.input" placeholder='{"key": "value"}'></textarea>
          </div>

          <button @click="runSimulation" :disabled="simulationRunning">
            {{ simulationRunning ? 'Running...' : 'Run Simulation' }}
          </button>
        </div>

        <div v-if="simulationResult" class="simulation-result">
          <h4>Simulation Result</h4>
          <pre>{{ JSON.stringify(simulationResult, null, 2) }}</pre>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import type { ReactorDevToolsState } from './devtools-plugin'

// State
const loading = ref(false)
const activeTab = ref('reactors')
const selectedReactor = ref(null)
const performanceTimeframe = ref(60)
const performanceAnalysis = ref(null)
const simulationRunning = ref(false)
const simulationResult = ref(null)

// DevTools data
const reactors = ref([])
const performance = ref({
  totalExecutions: 0,
  averageDuration: 0,
  successRate: 0,
  lastExecution: null
})
const alerts = ref([])

// Simulator state
const simulator = ref({
  name: 'test-reactor',
  steps: [
    { name: 'step-1', duration: 100, shouldFail: false },
    { name: 'step-2', duration: 200, shouldFail: false }
  ],
  input: '{"test": true}'
})

// Computed
const tabs = computed(() => [
  { id: 'reactors', label: 'Reactors', icon: 'carbon:flow', count: reactors.value.length },
  { id: 'performance', label: 'Performance', icon: 'carbon:analytics' },
  { id: 'alerts', label: 'Alerts', icon: 'carbon:warning', count: alerts.value.filter(a => a.type === 'error').length },
  { id: 'simulator', label: 'Simulator', icon: 'carbon:play' }
])

// Methods
async function refreshData() {
  loading.value = true
  try {
    const data = await $fetch('/__nuxt_devtools__/reactor/getReactorState')
    reactors.value = data.reactors
    performance.value = data.performance
    alerts.value = data.alerts
  } catch (error) {
    console.error('Failed to refresh reactor data:', error)
  } finally {
    loading.value = false
  }
}

async function clearHistory() {
  await $fetch('/__nuxt_devtools__/reactor/clearReactorHistory', { method: 'POST' })
  await refreshData()
}

async function exportData() {
  const data = await $fetch('/__nuxt_devtools__/reactor/exportReactorData', {
    method: 'POST',
    body: { format: 'json' }
  })
  
  const blob = new Blob([data], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `reactor-data-${Date.now()}.json`
  a.click()
  URL.revokeObjectURL(url)
}

async function analyzePerformance() {
  performanceAnalysis.value = await $fetch('/__nuxt_devtools__/reactor/analyzePerformance', {
    method: 'POST',
    body: { timeframe: performanceTimeframe.value }
  })
}

function addSimulatorStep() {
  simulator.value.steps.push({
    name: `step-${simulator.value.steps.length + 1}`,
    duration: 100,
    shouldFail: false
  })
}

async function runSimulation() {
  simulationRunning.value = true
  try {
    let input
    try {
      input = JSON.parse(simulator.value.input)
    } catch {
      input = simulator.value.input
    }

    simulationResult.value = await $fetch('/__nuxt_devtools__/reactor/simulateReactor', {
      method: 'POST',
      body: {
        name: simulator.value.name,
        steps: simulator.value.steps,
        input
      }
    })
    
    // Refresh data to show the simulated reactor
    await refreshData()
  } catch (error) {
    console.error('Simulation failed:', error)
    simulationResult.value = { error: error.message }
  } finally {
    simulationRunning.value = false
  }
}

// Utility functions
function formatDuration(ms) {
  if (!ms) return '-'
  if (ms < 1000) return `${ms}ms`
  return `${(ms / 1000).toFixed(1)}s`
}

function formatPercent(value) {
  if (value === undefined || value === null) return '-'
  return `${(value * 100).toFixed(1)}%`
}

function formatTime(timestamp) {
  return new Date(timestamp).toLocaleTimeString()
}

function getStepIcon(status) {
  switch (status) {
    case 'completed': return 'carbon:checkmark'
    case 'failed': return 'carbon:error'
    case 'running': return 'carbon:in-progress'
    default: return 'carbon:circle-dash'
  }
}

function getAlertIcon(type) {
  switch (type) {
    case 'error': return 'carbon:error'
    case 'warning': return 'carbon:warning'
    default: return 'carbon:information'
  }
}

// Initialize
onMounted(() => {
  refreshData()
  // Auto-refresh every 5 seconds
  setInterval(refreshData, 5000)
})
</script>

<style scoped>
.reactor-devtools {
  padding: 1rem;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid #e5e7eb;
}

.header h2 {
  margin: 0;
  color: #1f2937;
}

.header-actions {
  display: flex;
  gap: 0.5rem;
}

.header-actions button {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.5rem 1rem;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
  background: white;
  cursor: pointer;
}

.header-actions button:hover {
  background: #f9fafb;
}

.performance-overview {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 1rem;
  margin-bottom: 1rem;
}

.metric-card {
  padding: 1rem;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
  text-align: center;
}

.metric-value {
  font-size: 1.5rem;
  font-weight: bold;
  color: #1f2937;
}

.metric-label {
  font-size: 0.875rem;
  color: #6b7280;
}

.tabs {
  display: flex;
  border-bottom: 1px solid #e5e7eb;
  margin-bottom: 1rem;
}

.tabs button {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1rem;
  border: none;
  background: none;
  cursor: pointer;
  border-bottom: 2px solid transparent;
}

.tabs button.active {
  border-bottom-color: #3b82f6;
  color: #3b82f6;
}

.count {
  background: #ef4444;
  color: white;
  border-radius: 9999px;
  padding: 0.125rem 0.375rem;
  font-size: 0.75rem;
}

.reactors-tab {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  height: 500px;
}

.reactors-list {
  overflow-y: auto;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
}

.reactor-item {
  padding: 0.75rem;
  border-bottom: 1px solid #e5e7eb;
  cursor: pointer;
}

.reactor-item:hover {
  background: #f9fafb;
}

.reactor-item.executing {
  border-left: 3px solid #f59e0b;
}

.reactor-item.completed {
  border-left: 3px solid #10b981;
}

.reactor-item.failed {
  border-left: 3px solid #ef4444;
}

.reactor-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.25rem;
}

.reactor-id {
  font-weight: 500;
  font-family: monospace;
}

.reactor-status {
  padding: 0.125rem 0.5rem;
  border-radius: 0.25rem;
  font-size: 0.75rem;
  text-transform: uppercase;
}

.reactor-status.executing {
  background: #fef3c7;
  color: #92400e;
}

.reactor-status.completed {
  background: #d1fae5;
  color: #065f46;
}

.reactor-status.failed {
  background: #fee2e2;
  color: #991b1b;
}

.reactor-detail {
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
  padding: 1rem;
  overflow-y: auto;
}

.steps-list {
  margin: 0.5rem 0;
}

.step-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem;
  border-radius: 0.25rem;
}

.step-item.completed {
  background: #f0f9ff;
}

.step-item.failed {
  background: #fef2f2;
}

.step-error {
  color: #dc2626;
  font-size: 0.875rem;
}

.context-data {
  background: #f9fafb;
  border: 1px solid #e5e7eb;
  border-radius: 0.25rem;
  padding: 0.75rem;
  font-size: 0.875rem;
  overflow-x: auto;
}

.alerts-list {
  max-height: 500px;
  overflow-y: auto;
}

.alert-item {
  display: flex;
  align-items: start;
  gap: 0.75rem;
  padding: 0.75rem;
  border-bottom: 1px solid #e5e7eb;
}

.alert-item.error {
  background: #fef2f2;
}

.alert-item.warning {
  background: #fffbeb;
}

.simulator-form {
  max-width: 500px;
}

.form-group {
  margin-bottom: 1rem;
}

.form-group label {
  display: block;
  margin-bottom: 0.25rem;
  font-weight: 500;
}

.form-group input,
.form-group textarea,
.form-group select {
  width: 100%;
  padding: 0.5rem;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
}

.step-form {
  display: flex;
  gap: 0.5rem;
  align-items: center;
  margin-bottom: 0.5rem;
}

.step-form input[type="checkbox"] {
  width: auto;
}

.simulation-result {
  margin-top: 1rem;
  padding: 1rem;
  background: #f9fafb;
  border-radius: 0.5rem;
}
</style>
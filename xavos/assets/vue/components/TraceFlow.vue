<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'

interface TraceStep {
  id: string
  name: string
  status: 'pending' | 'running' | 'completed' | 'error'
  timestamp?: string
  duration?: number
  data?: any
  traceId?: string
}

// Props from LiveView
const props = defineProps<{
  currentTraceId?: string
  steps: TraceStep[]
  isRunning: boolean
}>()

// Local reactive state
const selectedStep = ref<string | null>(null)

// Emit to LiveView
const emit = defineEmits(['startTrace', 'resetTrace', 'stepClick'])

// Computed properties
const traceProgress = computed(() => {
  const completedSteps = props.steps.filter(step => step.status === 'completed').length
  return (completedSteps / props.steps.length) * 100
})

const currentStepIndex = computed(() => {
  return props.steps.findIndex(step => step.status === 'running')
})

const totalDuration = computed(() => {
  return props.steps
    .filter(step => step.duration)
    .reduce((sum, step) => sum + (step.duration || 0), 0)
})

// Methods
function startTrace() {
  emit('startTrace')
}

function resetTrace() {
  emit('resetTrace')
}

function handleStepClick(stepId: string) {
  selectedStep.value = stepId
  emit('stepClick', { stepId })
}

function getStepIcon(status: string) {
  switch (status) {
    case 'completed': return '✅'
    case 'running': return '⚡'
    case 'error': return '❌'
    default: return '⏳'
  }
}

function getStepColor(status: string) {
  switch (status) {
    case 'completed': return 'text-green-600 bg-green-50 border-green-200'
    case 'running': return 'text-blue-600 bg-blue-50 border-blue-200 animate-pulse'
    case 'error': return 'text-red-600 bg-red-50 border-red-200'
    default: return 'text-gray-600 bg-gray-50 border-gray-200'
  }
}

function formatDuration(ms?: number) {
  if (!ms) return 'N/A'
  return `${ms}ms`
}
</script>

<template>
  <div class="bg-white rounded-lg shadow-lg border border-gray-200 p-6">
    <div class="mb-6">
      <h3 class="text-xl font-bold text-gray-900 mb-2">
        Distributed Trace Flow
      </h3>
      <p class="text-gray-600 text-sm">
        Reactor → n8n → Reactor → LiveVue → Reactor
      </p>
      
      <!-- Trace ID Display -->
      <div v-if="props.currentTraceId" class="mt-4 p-3 bg-blue-50 rounded border border-blue-200">
        <span class="text-sm font-medium text-blue-800">Trace ID:</span>
        <code class="ml-2 text-sm font-mono text-blue-900">{{ props.currentTraceId }}</code>
      </div>
    </div>

    <!-- Progress Bar -->
    <div class="mb-6">
      <div class="flex justify-between text-sm text-gray-600 mb-2">
        <span>Progress</span>
        <span>{{ Math.round(traceProgress) }}%</span>
      </div>
      <div class="w-full bg-gray-200 rounded-full h-2">
        <div 
          class="bg-blue-600 h-2 rounded-full transition-all duration-500"
          :style="{ width: `${traceProgress}%` }"
        ></div>
      </div>
    </div>

    <!-- Control Buttons -->
    <div class="flex gap-3 mb-6">
      <button 
        @click="startTrace"
        :disabled="props.isRunning"
        class="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
      >
        {{ props.isRunning ? 'Running...' : 'Start Trace' }}
      </button>
      
      <button 
        @click="resetTrace"
        :disabled="props.isRunning"
        class="px-4 py-2 bg-gray-600 text-white rounded hover:bg-gray-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
      >
        Reset
      </button>
    </div>

    <!-- Steps Visualization -->
    <div class="space-y-3">
      <div 
        v-for="(step, index) in props.steps" 
        :key="step.id"
        @click="handleStepClick(step.id)"
        class="p-4 border rounded-lg cursor-pointer transition-all duration-200 hover:shadow-md"
        :class="[
          getStepColor(step.status),
          selectedStep === step.id ? 'ring-2 ring-blue-400' : '',
          currentStepIndex === index ? 'scale-[1.02]' : ''
        ]"
      >
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-3">
            <span class="text-lg">{{ getStepIcon(step.status) }}</span>
            <div>
              <h4 class="font-semibold">{{ step.name }}</h4>
              <p class="text-xs opacity-75">Step {{ index + 1 }} of {{ props.steps.length }}</p>
            </div>
          </div>
          
          <div class="text-right text-sm">
            <div v-if="step.timestamp" class="opacity-75">
              {{ new Date(step.timestamp).toLocaleTimeString() }}
            </div>
            <div v-if="step.duration" class="font-mono">
              {{ formatDuration(step.duration) }}
            </div>
          </div>
        </div>
        
        <!-- Step Details (when selected) -->
        <div v-if="selectedStep === step.id && step.data" class="mt-3 pt-3 border-t border-current border-opacity-20">
          <h5 class="font-medium text-sm mb-2">Step Data:</h5>
          <pre class="text-xs bg-black bg-opacity-10 p-2 rounded overflow-x-auto">{{ JSON.stringify(step.data, null, 2) }}</pre>
        </div>
      </div>
    </div>

    <!-- Summary Stats -->
    <div v-if="traceProgress > 0" class="mt-6 pt-4 border-t border-gray-200">
      <div class="grid grid-cols-2 gap-4 text-sm">
        <div class="text-center">
          <div class="font-semibold text-gray-900">Total Duration</div>
          <div class="text-gray-600">{{ formatDuration(totalDuration) }}</div>
        </div>
        <div class="text-center">
          <div class="font-semibold text-gray-900">Steps Completed</div>
          <div class="text-gray-600">
            {{ props.steps.filter(s => s.status === 'completed').length }} / {{ props.steps.length }}
          </div>
        </div>
      </div>
    </div>

    <!-- Real-time Status -->
    <div v-if="props.isRunning" class="mt-4 p-3 bg-yellow-50 border border-yellow-200 rounded">
      <div class="flex items-center">
        <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-yellow-600 mr-2"></div>
        <span class="text-yellow-800 text-sm">
          Trace execution in progress...
        </span>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Custom animations for trace flow */
.animate-pulse {
  animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
}

@keyframes pulse {
  0%, 100% {
    opacity: 1;
  }
  50% {
    opacity: .5;
  }
}

/* Smooth transitions for all elements */
* {
  transition: all 0.2s ease-in-out;
}
</style>
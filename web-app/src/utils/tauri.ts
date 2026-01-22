/**
 * Tauri Desktop API Utilities
 *
 * This file provides utilities for interacting with the Tauri desktop environment.
 * All functions safely check if running in Tauri before attempting native operations.
 */

// Check if running in Tauri desktop app
export const isTauriApp = (): boolean => {
  return typeof window !== 'undefined' && '__TAURI__' in window
}

// Lazy load Tauri API modules (only in desktop context)
export const getTauriAPI = async () => {
  if (!isTauriApp()) {
    throw new Error('Not running in Tauri app')
  }

  const { invoke } = await import('@tauri-apps/api/tauri')
  const { appWindow } = await import('@tauri-apps/api/window')
  const { open, save, message, ask, confirm } = await import('@tauri-apps/api/dialog')
  const {
    readTextFile,
    writeTextFile,
    readDir,
    createDir,
    removeFile,
    exists,
  } = await import('@tauri-apps/api/fs')
  const { appDataDir, downloadDir, documentDir } = await import('@tauri-apps/api/path')
  const { sendNotification } = await import('@tauri-apps/api/notification')

  return {
    invoke,
    window: appWindow,
    dialog: { open, save, message, ask, confirm },
    fs: { readTextFile, writeTextFile, readDir, createDir, removeFile, exists },
    path: { appDataDir, downloadDir, documentDir },
    notification: { sendNotification },
  }
}

/**
 * Get application version
 */
export const getAppVersion = async (): Promise<string> => {
  if (!isTauriApp()) return 'Web'

  try {
    const { invoke } = await getTauriAPI()
    return await invoke<string>('get_app_version')
  } catch (error) {
    console.error('Failed to get app version:', error)
    return 'Unknown'
  }
}

/**
 * Check for app updates
 */
export const checkForUpdates = async (): Promise<string> => {
  if (!isTauriApp()) throw new Error('Updates only available in desktop app')

  const { invoke, window } = await getTauriAPI()
  return await invoke<string>('check_for_updates', { window })
}

/**
 * Show native notification
 */
export const showNotification = async (title: string, body: string): Promise<void> => {
  if (!isTauriApp()) {
    // Fallback to browser notification
    if ('Notification' in window && Notification.permission === 'granted') {
      new Notification(title, { body })
    }
    return
  }

  const { notification } = await getTauriAPI()
  await notification.sendNotification({ title, body })
}

/**
 * Show native dialog
 */
export const showDialog = async (
  message: string,
  type: 'info' | 'warning' | 'error' = 'info'
): Promise<void> => {
  if (!isTauriApp()) {
    alert(message)
    return
  }

  const { dialog } = await getTauriAPI()
  await dialog.message(message, { title: 'ThirdBooks', type })
}

/**
 * Show confirmation dialog
 */
export const showConfirm = async (message: string, title = 'Confirm'): Promise<boolean> => {
  if (!isTauriApp()) {
    return confirm(message)
  }

  const { dialog } = await getTauriAPI()
  return await dialog.confirm(message, { title, type: 'warning' })
}

/**
 * Open file picker
 */
export const openFilePicker = async (
  options?: {
    multiple?: boolean
    filters?: Array<{ name: string; extensions: string[] }>
    directory?: boolean
  }
): Promise<string | string[] | null> => {
  if (!isTauriApp()) {
    throw new Error('File picker only available in desktop app')
  }

  const { dialog } = await getTauriAPI()
  return await dialog.open({
    multiple: options?.multiple ?? false,
    directory: options?.directory ?? false,
    filters: options?.filters,
  })
}

/**
 * Save file dialog
 */
export const saveFilePicker = async (
  defaultPath?: string,
  filters?: Array<{ name: string; extensions: string[] }>
): Promise<string | null> => {
  if (!isTauriApp()) {
    throw new Error('Save dialog only available in desktop app')
  }

  const { dialog } = await getTauriAPI()
  return await dialog.save({ defaultPath, filters })
}

/**
 * Read file from filesystem
 */
export const readFile = async (path: string): Promise<string> => {
  if (!isTauriApp()) {
    throw new Error('File system access only available in desktop app')
  }

  const { fs } = await getTauriAPI()
  return await fs.readTextFile(path)
}

/**
 * Write file to filesystem
 */
export const writeFile = async (path: string, contents: string): Promise<void> => {
  if (!isTauriApp()) {
    throw new Error('File system access only available in desktop app')
  }

  const { fs } = await getTauriAPI()
  await fs.writeTextFile(path, contents)
}

/**
 * Export data to file
 */
export const exportToFile = async (
  data: string,
  defaultFileName: string,
  fileType: 'csv' | 'json' | 'pdf' = 'csv'
): Promise<void> => {
  if (!isTauriApp()) {
    // Fallback to browser download
    const blob = new Blob([data], { type: `text/${fileType}` })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = defaultFileName
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
    return
  }

  const filters = [
    { name: fileType.toUpperCase(), extensions: [fileType] },
  ]

  const filePath = await saveFilePicker(defaultFileName, filters)

  if (filePath) {
    await writeFile(filePath, data)
    await showNotification('Export Successful', `File saved to ${filePath}`)
  }
}

/**
 * Get application data directory path
 */
export const getAppDataPath = async (): Promise<string> => {
  if (!isTauriApp()) {
    throw new Error('App data path only available in desktop app')
  }

  const { path } = await getTauriAPI()
  return await path.appDataDir()
}

/**
 * Minimize window
 */
export const minimizeWindow = async (): Promise<void> => {
  if (!isTauriApp()) return

  const { window } = await getTauriAPI()
  await window.minimize()
}

/**
 * Maximize window
 */
export const maximizeWindow = async (): Promise<void> => {
  if (!isTauriApp()) return

  const { window } = await getTauriAPI()
  await window.maximize()
}

/**
 * Close window
 */
export const closeWindow = async (): Promise<void> => {
  if (!isTauriApp()) {
    window.close()
    return
  }

  const { window } = await getTauriAPI()
  await window.close()
}

/**
 * Toggle fullscreen
 */
export const toggleFullscreen = async (): Promise<void> => {
  if (!isTauriApp()) return

  const { window } = await getTauriAPI()
  const isFullscreen = await window.isFullscreen()
  await window.setFullscreen(!isFullscreen)
}

/**
 * Desktop-specific features detection
 */
export const desktopFeatures = {
  hasFileSystem: isTauriApp(),
  hasNativeDialogs: isTauriApp(),
  hasSystemTray: isTauriApp(),
  hasAutoUpdates: isTauriApp(),
  hasOfflineStorage: isTauriApp(),
}

/**
 * Export utilities for use in components
 */
export default {
  isTauriApp,
  getAppVersion,
  checkForUpdates,
  showNotification,
  showDialog,
  showConfirm,
  openFilePicker,
  saveFilePicker,
  readFile,
  writeFile,
  exportToFile,
  getAppDataPath,
  minimizeWindow,
  maximizeWindow,
  closeWindow,
  toggleFullscreen,
  desktopFeatures,
}

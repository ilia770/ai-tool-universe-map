import { Component, type ErrorInfo, type ReactNode } from 'react';

interface Props {
  children: ReactNode;
  fallback: ReactNode;
}

interface State {
  hasError: boolean;
}

/**
 * Catches errors thrown while mounting or rendering the lazy 3D scene — most
 * importantly a WebGL context that fails to initialise (GPU-blocklisted /
 * locked-down browsers), which otherwise unmounts the subtree and leaves a
 * blank panel with no explanation. Runtime context *loss* is handled inside
 * Scene via the canvas's webglcontextlost event; this boundary covers the
 * harder failure where the context never comes up at all.
 */
export class WebGLErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false };

  static getDerivedStateFromError(): State {
    return { hasError: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('3D scene failed to render', error, info.componentStack);
  }

  render() {
    return this.state.hasError ? this.props.fallback : this.props.children;
  }
}

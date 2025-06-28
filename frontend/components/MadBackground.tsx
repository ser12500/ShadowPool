"use client";

import { useEffect, useRef } from 'react';
import * as THREE from 'three';
import { gsap } from 'gsap';

export default function MadBackground() {
    const mountRef = useRef<HTMLDivElement>(null);
    const sceneRef = useRef<THREE.Scene | null>(null);
    const rendererRef = useRef<THREE.WebGLRenderer | null>(null);
    const particlesRef = useRef<THREE.Points | null>(null);
    const animationIdRef = useRef<number | null>(null);

    useEffect(() => {
        if (!mountRef.current) return;

        // Создаем сцену
        const scene = new THREE.Scene();
        sceneRef.current = scene;

        // Создаем камеру
        const camera = new THREE.PerspectiveCamera(
            75,
            window.innerWidth / window.innerHeight,
            0.1,
            1000
        );
        camera.position.z = 5;

        // Создаем рендерер
        const renderer = new THREE.WebGLRenderer({
            alpha: true,
            antialias: true,
            powerPreference: "high-performance"
        });
        renderer.setSize(window.innerWidth, window.innerHeight);
        renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
        rendererRef.current = renderer;
        mountRef.current.appendChild(renderer.domElement);

        // Создаем безумные частицы
        const particleCount = 2000;
        const positions = new Float32Array(particleCount * 3);
        const colors = new Float32Array(particleCount * 3);
        const sizes = new Float32Array(particleCount);

        for (let i = 0; i < particleCount; i++) {
            positions[i * 3] = (Math.random() - 0.5) * 20;
            positions[i * 3 + 1] = (Math.random() - 0.5) * 20;
            positions[i * 3 + 2] = (Math.random() - 0.5) * 20;

            colors[i * 3] = Math.random();
            colors[i * 3 + 1] = Math.random();
            colors[i * 3 + 2] = Math.random();

            sizes[i] = Math.random() * 3 + 1;
        }

        const geometry = new THREE.BufferGeometry();
        geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
        geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
        geometry.setAttribute('size', new THREE.BufferAttribute(sizes, 1));

        // Создаем шейдеры для безумных эффектов
        const vertexShader = `
      attribute float size;
      attribute vec3 color;
      varying vec3 vColor;
      varying float vAlpha;
      uniform float time;
      
      void main() {
        vColor = color;
        vec3 pos = position;
        
        // Безумная анимация
        pos.x += sin(time * 0.001 + position.y * 0.1) * 0.5;
        pos.y += cos(time * 0.001 + position.x * 0.1) * 0.5;
        pos.z += sin(time * 0.002 + position.x * 0.05) * 0.3;
        
        vAlpha = (sin(time * 0.001 + position.x * 0.1) + 1.0) * 0.5;
        
        vec4 mvPosition = modelViewMatrix * vec4(pos, 1.0);
        gl_PointSize = size * (300.0 / -mvPosition.z);
        gl_Position = projectionMatrix * mvPosition;
      }
    `;

        const fragmentShader = `
      varying vec3 vColor;
      varying float vAlpha;
      uniform float time;
      
      void main() {
        vec2 center = gl_PointCoord - 0.5;
        float dist = length(center);
        
        if (dist > 0.5) discard;
        
        float alpha = 1.0 - dist * 2.0;
        alpha *= vAlpha;
        
        vec3 color = vColor;
        color += sin(time * 0.01) * 0.3;
        
        gl_FragColor = vec4(color, alpha * 0.6);
      }
    `;

        const material = new THREE.ShaderMaterial({
            vertexShader,
            fragmentShader,
            transparent: true,
            blending: THREE.AdditiveBlending,
            depthWrite: false,
            uniforms: {
                time: { value: 0 }
            }
        });

        const particles = new THREE.Points(geometry, material);
        particlesRef.current = particles;
        scene.add(particles);

        // Создаем безумные волны
        const waveGeometry = new THREE.PlaneGeometry(20, 20, 50, 50);
        const waveMaterial = new THREE.ShaderMaterial({
            vertexShader: `
        uniform float time;
        varying vec3 vPosition;
        
        void main() {
          vPosition = position;
          vec3 pos = position;
          
          // Безумные волны
          pos.z += sin(time * 0.002 + position.x * 0.5) * 0.5;
          pos.z += cos(time * 0.003 + position.y * 0.5) * 0.3;
          pos.z += sin(time * 0.001 + position.x * 0.2 + position.y * 0.2) * 0.2;
          
          gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
        }
      `,
            fragmentShader: `
        uniform float time;
        varying vec3 vPosition;
        
        void main() {
          float alpha = 0.1;
          alpha += sin(time * 0.001 + vPosition.x * 0.5) * 0.05;
          alpha += cos(time * 0.002 + vPosition.y * 0.5) * 0.05;
          
          gl_FragColor = vec4(0.5, 0.3, 1.0, alpha);
        }
      `,
            transparent: true,
            side: THREE.DoubleSide,
            uniforms: {
                time: { value: 0 }
            }
        });

        const waves = new THREE.Mesh(waveGeometry, waveMaterial);
        waves.rotation.x = -Math.PI / 2;
        waves.position.z = -5;
        scene.add(waves);

        // Анимация
        let time = 0;
        const animate = () => {
            time += 16;

            if (particlesRef.current) {
                const material = particlesRef.current.material as THREE.ShaderMaterial;
                if (material.uniforms) {
                    material.uniforms.time.value = time;
                }
                particlesRef.current.rotation.x += 0.001;
                particlesRef.current.rotation.y += 0.002;
            }

            if (waves) {
                const waveMaterial = waves.material as THREE.ShaderMaterial;
                if (waveMaterial.uniforms) {
                    waveMaterial.uniforms.time.value = time;
                }
            }

            // Безумное движение камеры
            camera.position.x = Math.sin(time * 0.0005) * 2;
            camera.position.y = Math.cos(time * 0.0003) * 1;
            camera.lookAt(0, 0, 0);

            renderer.render(scene, camera);
            animationIdRef.current = requestAnimationFrame(animate);
        };

        animate();

        // Обработчик изменения размера окна
        const handleResize = () => {
            camera.aspect = window.innerWidth / window.innerHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(window.innerWidth, window.innerHeight);
        };

        window.addEventListener('resize', handleResize);

        // Безумные GSAP анимации
        gsap.to(camera.position, {
            z: 3,
            duration: 2,
            ease: "power2.out"
        });

        gsap.to(particles.rotation, {
            x: Math.PI * 2,
            duration: 20,
            repeat: -1,
            ease: "none"
        });

        return () => {
            window.removeEventListener('resize', handleResize);
            if (animationIdRef.current) {
                cancelAnimationFrame(animationIdRef.current);
            }
            if (mountRef.current && renderer.domElement) {
                mountRef.current.removeChild(renderer.domElement);
            }
            renderer.dispose();
        };
    }, []);

    return (
        <div
            ref={mountRef}
            className="fixed inset-0 pointer-events-none z-0"
            style={{ background: 'linear-gradient(135deg, #0f0f23 0%, #1a1a2e 50%, #16213e 100%)' }}
        />
    );
} 
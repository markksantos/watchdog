import React from 'react';
import {
  AbsoluteFill, Img, Sequence, staticFile,
  interpolate, spring, useCurrentFrame, useVideoConfig,
} from 'remotion';

const RED = '#FF3B30';
const FONT = "'Helvetica Neue', Helvetica, Arial, sans-serif";

const Scrim: React.FC<{reach?: number; strength?: number}> = ({reach = 0.6, strength = 0.72}) => (
  <AbsoluteFill
    style={{
      background: `linear-gradient(90deg, rgba(6,6,8,${strength}) 0%, rgba(6,6,8,${strength * 0.7}) ${reach * 50}%, rgba(6,6,8,0) ${reach * 100}%)`,
    }}
  />
);

// One feature scene: cinematic bg + real UI window sliding up + caption fading in.
const Feature: React.FC<{
  bg: string; win: string; eyebrow: string; title: string; sub: string;
}> = ({bg, win, eyebrow, title, sub}) => {
  const frame = useCurrentFrame();
  const {fps, durationInFrames} = useVideoConfig();

  const winSpring = spring({frame: frame - 6, fps, config: {damping: 200, mass: 0.9}});
  const winY = interpolate(winSpring, [0, 1], [70, 0]);
  const winOpacity = interpolate(frame, [6, 24], [0, 1], {extrapolateRight: 'clamp'});
  const kenBurns = interpolate(frame, [0, durationInFrames], [1.06, 1.14]);
  const textX = interpolate(spring({frame: frame - 2, fps, config: {damping: 200}}), [0, 1], [-40, 0]);
  const textOpacity = interpolate(frame, [2, 20], [0, 1], {extrapolateRight: 'clamp'});
  const fadeOut = interpolate(frame, [durationInFrames - 14, durationInFrames], [1, 0], {extrapolateLeft: 'clamp'});

  return (
    <AbsoluteFill style={{backgroundColor: '#0a0a0c', opacity: fadeOut}}>
      <AbsoluteFill style={{transform: `scale(${kenBurns})`}}>
        <Img src={staticFile(bg)} style={{width: '100%', height: '100%', objectFit: 'cover'}} />
      </AbsoluteFill>
      <Scrim />

      {/* app window, right side */}
      <div
        style={{
          position: 'absolute', right: 120, top: '50%',
          transform: `translateY(calc(-50% + ${winY}px))`, opacity: winOpacity,
        }}
      >
        <div style={{position: 'absolute', inset: -3, borderRadius: 22, boxShadow: `0 0 90px ${RED}55`}} />
        <Img
          src={staticFile(win)}
          style={{height: 720, borderRadius: 20, boxShadow: '0 50px 110px rgba(0,0,0,0.65)', display: 'block'}}
        />
      </div>

      {/* caption, left */}
      <div style={{position: 'absolute', left: 130, top: 340, width: 760, transform: `translateX(${textX}px)`, opacity: textOpacity}}>
        <div style={{color: RED, font: `700 24px ${FONT}`, letterSpacing: 4, marginBottom: 18}}>{eyebrow}</div>
        <div style={{color: '#fff', font: `700 76px ${FONT}`, lineHeight: 1.05, letterSpacing: -1}}>{title}</div>
        <div style={{color: '#cececf', font: `400 32px ${FONT}`, marginTop: 24, lineHeight: 1.35}}>{sub}</div>
      </div>
    </AbsoluteFill>
  );
};

const Intro: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const s = spring({frame, fps, config: {damping: 200, mass: 1.1}});
  const iconScale = interpolate(s, [0, 1], [0.6, 1]);
  const iconOpacity = interpolate(frame, [0, 20], [0, 1], {extrapolateRight: 'clamp'});
  const textOpacity = interpolate(frame, [22, 44], [0, 1], {extrapolateRight: 'clamp'});
  const fadeOut = interpolate(frame, [76, 90], [1, 0], {extrapolateLeft: 'clamp'});
  const pulse = 1 + 0.03 * Math.sin(frame / 8);

  return (
    <AbsoluteFill style={{backgroundColor: '#0a0a0c', opacity: fadeOut, alignItems: 'center', justifyContent: 'center'}}>
      <Img src={staticFile('promo_hero_bg.jpg')} style={{position: 'absolute', width: '100%', height: '100%', objectFit: 'cover', opacity: 0.5}} />
      <div style={{position: 'absolute', width: 640, height: 640, borderRadius: 999, background: `radial-gradient(circle, ${RED}44 0%, transparent 62%)`, opacity: iconOpacity}} />
      <Img src={staticFile('icon.png')} style={{width: 260, height: 260, borderRadius: 58, transform: `scale(${iconScale * pulse})`, opacity: iconOpacity, boxShadow: `0 30px 90px ${RED}44`}} />
      <div style={{marginTop: 44, textAlign: 'center', opacity: textOpacity}}>
        <div style={{color: '#fff', font: `700 92px ${FONT}`, letterSpacing: -2}}>Watchdog</div>
        <div style={{color: '#d6d6da', font: `500 40px ${FONT}`, marginTop: 12}}>See who walked up to your Mac</div>
      </div>
    </AbsoluteFill>
  );
};

const Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const s = spring({frame, fps, config: {damping: 200}});
  const scale = interpolate(s, [0, 1], [0.8, 1]);
  const opacity = interpolate(frame, [0, 18], [0, 1], {extrapolateRight: 'clamp'});
  return (
    <AbsoluteFill style={{backgroundColor: '#0a0a0c', alignItems: 'center', justifyContent: 'center'}}>
      <div style={{position: 'absolute', width: 700, height: 700, borderRadius: 999, background: `radial-gradient(circle, ${RED}33 0%, transparent 60%)`}} />
      <div style={{textAlign: 'center', transform: `scale(${scale})`, opacity}}>
        <Img src={staticFile('icon.png')} style={{width: 200, height: 200, borderRadius: 46, boxShadow: `0 30px 90px ${RED}44`}} />
        <div style={{color: '#fff', font: `700 76px ${FONT}`, letterSpacing: -1.5, marginTop: 34}}>Watchdog</div>
        <div style={{color: RED, font: `600 30px ${FONT}`, letterSpacing: 2, marginTop: 14}}>LOCAL MAC SECURITY</div>
        <div style={{color: '#9a9aa2', font: `400 28px ${FONT}`, marginTop: 20}}>Captures stay on your device. Never the cloud.</div>
      </div>
    </AbsoluteFill>
  );
};

export const WatchdogPreview: React.FC = () => {
  const D = 108; // feature scene length
  const features = [
    {bg: 'bg_detection.jpg', win: 'win_camera.jpg', eyebrow: 'DETECTION', title: 'Three ways to watch', sub: 'Face, motion, or an always-on timer — switch in a tap.'},
    {bg: 'bg_quality.jpg', win: 'win_recording.jpg', eyebrow: 'QUALITY', title: 'Capture in crisp detail', sub: 'From 480p to 4K, with independent quality control.'},
    {bg: 'bg_appearance.jpg', win: 'win_appearance.jpg', eyebrow: 'APPEARANCE', title: 'Make it yours', sub: 'Six accent themes, light or dark, your menu bar icon.'},
    {bg: 'bg_alerts.jpg', win: 'win_alerts.jpg', eyebrow: 'ALERTS', title: 'Know the moment it happens', sub: 'A siren, a screen flash, or a quiet notification.'},
    {bg: 'bg_privacy.jpg', win: 'win_storage.jpg', eyebrow: 'PRIVACY', title: 'Everything stays on your Mac', sub: 'No account, no analytics, no network connections.'},
  ];
  return (
    <AbsoluteFill style={{backgroundColor: '#0a0a0c'}}>
      <Sequence durationInFrames={90}><Intro /></Sequence>
      {features.map((f, i) => (
        <Sequence key={i} from={90 + i * D} durationInFrames={D}>
          <Feature {...f} />
        </Sequence>
      ))}
      <Sequence from={90 + features.length * D}><Outro /></Sequence>
    </AbsoluteFill>
  );
};

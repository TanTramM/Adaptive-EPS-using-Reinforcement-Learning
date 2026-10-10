function g = map_noise_gain(k, z, p, Ts)
%MAP_NOISE_GAIN RMS gain from white sensor noise on T_s to the assist command of the Map path k*H(s)*Gm(s).
%   Noise of a signal updated every Ts is taken as white up to the Nyquist frequency pi/Ts (flat spectrum).
%   g = sqrt( (1/wN) * integral_0^wN |k H(jw) Gm(jw)|^2 dw ). T_a noise std = g * sigma_Ts.
if nargin < 4, Ts = 1e-3; end
wm = 2 * pi * 100;
wN = pi / Ts;
w = linspace(0, wN, 20000)';
if isinf(z)
    H = ones(size(w));
else
    H = (1i * w / z + 1) ./ (1i * w / p + 1);
end
F = k * H .* (wm ./ (1i * w + wm));
g = sqrt(trapz(w, abs(F).^2) / wN);
end

